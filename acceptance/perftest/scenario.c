#include "scenario.h"
#include "stats.h"
#include <curl/curl.h>
#include <stdlib.h>
#include <math.h>

static char*  target                   = NULL;
static char*  esxi_uuid                = NULL;
static char*  ubuntu_uuid              = NULL;
static char*  mk_uuid                  = NULL;
static guint  load                     = 30;
static guint  population               = 20000;
static guint  max_cycles               = 600;
static double physical_refresh_percent = 0.025; /* 2.5 percent per day */
static double virtual_refresh_percent  = 0.200; /* 20 percent per day */
static guint  virtual_per_physical     = 20;    /* VM multiplier */

static GOptionEntry options[] = {
  { "target", 0, 0, G_OPTION_ARG_STRING, &target,
    "The Razor server to run performance tests against", "HOST" },
  { "esxi-uuid", 0, 0, G_OPTION_ARG_STRING, &esxi_uuid,
    "The Razor ESXi OS image UUID", "UUID" },
  { "ubuntu-uuid", 0, 0, G_OPTION_ARG_STRING, &ubuntu_uuid,
    "The Razor Ubuntu OS image UUID", "UUID" },
  { "mk-uuid", 0, 0, G_OPTION_ARG_STRING, &mk_uuid,
    "The Razor MK image UUID", "UUID" },
  { "max",  'm', 0, G_OPTION_ARG_INT, &max_cycles,
    "Maximum seconds runtime", "SECONDS" },
  { "load", 'l', 0, G_OPTION_ARG_INT, &load,
    "How many simulated refresh events to perform", "COUNT" },
  { "population", 'p', 0, G_OPTION_ARG_INT, &population,
    "How many physical nodes in the population", "NODES" },
  { NULL }
};


static Event* event_new_with_url(ScenarioPart* parent, const char* url) {
  Event* event          = g_new0(Event, 1);
  event->scenario_part  = parent;
  event->url            = g_strdup(url);
  event->expect_success = TRUE;
  return event;
}




static Scenario* scenario_new(const char* name) {
  Scenario* scenario = g_new0(Scenario, 1);
  scenario->name  = g_strdup(name);
  return scenario;
}

static struct {
  gchar*  name;
  gchar** value;
} replace_find_var_table[] = {
  { "target",      &target      },
  { "esxi_uuid",   &esxi_uuid   },
  { "ubuntu_uuid", &ubuntu_uuid },
  { "mk_uuid",     &mk_uuid     },
  { NULL }
};

static gboolean replace_find_var(
  const GMatchInfo* info, GString* result, gpointer data_
) {
  gchar* match = g_match_info_fetch(info, 1);

  for (int i = 0; replace_find_var_table[i].name; ++i) {
    if (g_strcmp0(match, replace_find_var_table[i].name) == 0) {
      gchar* value = *(replace_find_var_table[i].value);

      if (result) {
        g_string_append(result, value);
        g_free(match);
        return FALSE;           /* continue replacing */
      }

      g_critical("no value for replacement %s found", match);
      exit(1);
    }
  }

  g_critical("unknown replacement %s found", match);
  exit(1);
}


static void scenario_add_part_from_file(
  Scenario*   scenario,
  const char* name,
  const char* target,
  const char* filename
) {
  ScenarioPart* part = g_new0(ScenarioPart, 1);
  part->scenario = scenario;
  part->name     = g_strdup(name);
  part->events   = g_ptr_array_new();

  gchar*  content = NULL;
  GError* error   = NULL;

  if (!g_file_get_contents(filename, &content, NULL, &error) || error) {
    g_critical("failed to read %s: %s", filename, error->message);
    exit(1);
  }

  gchar** urls = g_strsplit(content, "\n", -1);
  g_free(content);

  GRegex* pattern = g_regex_new("\\${([^}]+)}", 0, 0, &error);
  if (error || !pattern) {
    g_critical("failed to compile regex: %s", error->message);
    exit(1);
  }

  for (int i = 0; urls[i]; ++i) {
    gchar* url = g_regex_replace_eval(
      pattern,                  /* pattern to match */
      urls[i], -1,              /* content to match on, and strlen */
      0,                        /* start position */
      0,                        /* match options */
      replace_find_var, NULL,   /* eval callback, user arg to callback */
      &error
    );
    if (error) {
      g_critical("regex replace failure in %s - '%s':\n%s",
                 filename, url, error->message);
      exit(1);
    }

    g_ptr_array_add(part->events, event_new_with_url(part, url));
  }

  g_strfreev(urls);
  g_regex_unref(pattern);

  scenario->parts = g_list_append(scenario->parts, part);
}


#define curlopt(curl, option, value)                          \
  do {                                                        \
    CURLcode c = curl_easy_setopt(curl, option, value);       \
    if (c != CURLE_OK) {                                      \
      g_critical("failed setting CURL %s: %s",                \
              #option, curl_easy_strerror(c));                \
      exit(1);                                                \
    }                                                         \
  } while (0)

typedef struct EventClosure {
  TestSuite* suite;
  CURL*      curl;
} EventClosure;

static size_t scenario_track_curl_write(
  char *p, size_t size, size_t count, void *userdata
) {
  EventFinished* data = userdata;

  if (!data->first_data)
    data->first_data = g_get_monotonic_time();

  data->bytes += size * count;

  return size * count;
}

static void scenario_run_event(const Event* event, EventClosure* closure) {
  EventFinished *data = stats_event_finished_new(event);

  curlopt(closure->curl, CURLOPT_URL,       event->url);
  curlopt(closure->curl, CURLOPT_WRITEDATA, data);

  data->start  = g_get_monotonic_time();
  CURLcode c   = curl_easy_perform(closure->curl);
  data->finish = g_get_monotonic_time();

  switch (c) {
  case CURLE_OK:
    data->successful = event->expect_success;
    break;

  default:
    data->successful = !event->expect_success;
    break;
  }

  stats_event_finished(closure->suite->stats, data);
}


TestSuite* test_suite_setup(int* argc, char*** argv) {
  GError*         error   = NULL;
  GOptionContext* context = g_option_context_new("- test Razor server performance");
  g_option_context_add_main_entries(context, options, "perftest alpha");
  if (!g_option_context_parse(context, argc, argv, &error)) {
    g_print("error: %s\n", error->message);
    exit(1);
  }

  TestSuite* suite = g_new0(TestSuite, 1);
  suite->stats = stats_new(suite);

  /* calculate our run rates, etc */
  suite->max_cycles               = max_cycles;
  suite->target                   = target;
  suite->load                     = load;
  suite->physical_nodes           = population;
  suite->virtual_nodes            = population * virtual_per_physical;
  suite->nodes                    = suite->physical_nodes +
                                    suite->virtual_nodes;
  suite->physical_refresh_percent = physical_refresh_percent;
  suite->virtual_refresh_percent  = virtual_refresh_percent;
  suite->virtual_per_physical     = virtual_per_physical;

  const double physical_refreshes_per_day =
    ((double)suite->physical_nodes * suite->physical_refresh_percent);
  const double virtual_refreshes_per_day =
    ((double)suite->virtual_nodes  * suite->virtual_refresh_percent);

  suite->physical_refreshes_per_second =
    MAX(physical_refreshes_per_day / (double)86400, 0.01);

  suite->virtual_refreshes_per_second =
    MAX(virtual_refreshes_per_day / (double)86400, 0.01);

  /* now, how many total events of each type to reach a load of $load? */
  const double total_refreshes_per_second =
    suite->physical_refreshes_per_second + suite->virtual_refreshes_per_second;

  const double seconds_to_hit_load = (double)load / total_refreshes_per_second;

  suite->physical_refresh_events =
    ceil(seconds_to_hit_load * suite->physical_refreshes_per_second);
  suite->virtual_refresh_events =
    ceil(seconds_to_hit_load * suite->virtual_refreshes_per_second);

  suite->approximate_runtime = MAX(
    ceil(((double)suite->physical_refresh_events - 1)
         / suite->physical_refreshes_per_second),
    ceil(((double)suite->virtual_refresh_events - 1)
         / suite->virtual_refreshes_per_second)
  );

  /* create the set of scenarios, and make them available */
  suite->esxi = scenario_new("esxi");
  scenario_add_part_from_file(suite->esxi, "initial PXE", target, "pxe.scenario");
  scenario_add_part_from_file(suite->esxi, "microkernel", target, "mk.scenario");
  scenario_add_part_from_file(suite->esxi, "PXE",         target, "pxe.scenario");
  scenario_add_part_from_file(suite->esxi, "install",     target, "esxi.scenario");

  suite->ubuntu = scenario_new("ubuntu");
  scenario_add_part_from_file(suite->ubuntu, "initial PXE", target, "pxe.scenario");
  scenario_add_part_from_file(suite->ubuntu, "microkernel", target, "mk.scenario");
  scenario_add_part_from_file(suite->ubuntu, "PXE",         target, "pxe.scenario");
  scenario_add_part_from_file(suite->ubuntu, "install",     target, "ubuntu.scenario");

  return suite;
}

void test_suite_run(TestSuite* suite) {
  suite->start_time = g_get_monotonic_time();
  g_main_loop_run(suite->loop);
  suite->end_time  = g_get_monotonic_time();
}


void scenario_handler(const Scenario* scenario, TestSuite* suite) {
  EventClosure closure = {
    .suite = suite,
    .curl  = curl_easy_init()
  };

  curlopt(closure.curl, CURLOPT_VERBOSE, 0);
  curlopt(closure.curl, CURLOPT_WRITEFUNCTION, scenario_track_curl_write);
  curlopt(closure.curl, CURLOPT_FOLLOWLOCATION, 1);
  curlopt(closure.curl, CURLOPT_MAXREDIRS, 7);

  for (GList* entry = scenario->parts; entry; entry = entry->next) {
    ScenarioPart* part = entry->data;
    g_ptr_array_foreach(part->events, (GFunc)scenario_run_event, &closure);
  }

  curl_easy_cleanup(closure.curl);
}
