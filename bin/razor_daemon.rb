#!/usr/bin/env ruby
#
# A daemon that is used to start, stop, restart, etc. the underlying Node.js
# instances that make up Razor and to ensure that they stay running as long
# as this daemon process continues to run.  It also checks the status of the
# underlying database instance that is used by Razor to ensure that it is
# running and throws an error (and exits) if that database stops running.
# Finally, this daemon will be used to check the timings on tasks that are
# running under Razor, but that functionality is, as of now, unimplemented.
#

require 'rubygems'
require 'daemons'
require 'json'
require 'pathname'

# add our the Razor lib path to the load path. This is for non-gem ease of use
bin_dir = Pathname(__FILE__).realpath.dirname.to_s
lib_path = bin_dir.sub(/\/bin$/,"/lib")
$LOAD_PATH.unshift(lib_path)
# We require the root lib
require 'project_razor'

# used in cases where the Razor server configuration file does not have a
# parameter value for the daemon_min_cycle_time
DEFAULT_MIN_CYCLE_TIME = 30

# used in cases where the Razor server configuration file does not have a
# parameter value for the node_expire_timeout (uses a 15 minute default)
DEFAULT_NODE_EXPIRE_TIMEOUT = 60 * 15

# monkey-patch the Daemons::Application class so that it uses a pattern of "*.log" for
# the file that it uses to capture output from the Daemon (and the processes that it
# manages) rather than the default pattern used by this class ("*.output")
#
# monkey-patch Daemons status so it returns proper exit codes.
module Daemons
  class Application
    def output_logfile
      (options[:log_output] && logdir) ? File.join(logdir, @group.app_name + '.log') : nil
    end

    def show_status
      running = self.running?

      puts "#{self.group.app_name}: #{running ? '' : 'not '}running#{(running and @pid.exist?) ? ' [pid ' + @pid.pid.to_s + ']' : ''}#{(@pid.exist? and not running) ? ' (but pid-file exists: ' + @pid.pid.to_s + ')' : ''}"
      exit(1) unless running
    end
  end

  class Controller
    def run
      @options.update @optparse.parse(@controller_part).delete_if {|k,v| !v}

      setup_options()

      #pp @options

      @group = ApplicationGroup.new(@app_name, @options)
      @group.controller_argv = @controller_part
      @group.app_argv = @app_part

      @group.setup

      case @command
      when 'start'
        @group.new_application.start
      when 'run'
        @options[:ontop] ||= true
        @group.new_application.start
      when 'stop'
        @group.stop_all
      when 'restart'
        unless @group.applications.empty?
          @group.stop_all
          sleep 1
          @group.start_all
        else
          puts "Warning: no instances running. Starting..."
          @group.new_application.start
        end
      when 'zap'
        @group.zap_all
      when 'status'
        unless @group.applications.empty?
          @group.show_status
        else
          puts "#{@group.app_name}: no instances running"
          exit(3)
        end
      when nil
        raise CmdException.new('no command given')
        #puts "ERROR: No command given"; puts

        #print_usage()
        #raise('usage function not implemented')
      else
        raise Error.new("command '#{@command}' not implemented")
      end
    end
  end
end

# This singleton class is used by the daemon (below) to interact with the
# underlying Razor (obtaining a copy of the Razor server configuration and
# managing the underlying services that make up the Razor server).  It is
# also used to verify that services critical to Razor are running (the daemon
# will actually throw an error and shut down the Razor server if these
# critical services are found to be missing during a pass through the
# daemon's event-handling loop)
class RazorDaemon < ProjectRazor::Object
  include Singleton

  BIN_DIR = Pathname(__FILE__).realpath.dirname.to_s
  NODE_COMMAND = %x[which nodejs || which node].strip
  NODE_INSTANCE_NAMES = %W[api.js image_svc.js]
  NODE_COMMAND_MAP = { 'api.js' => "#{NODE_COMMAND} #{BIN_DIR}/api.js",
                       'image_svc.js' => "#{NODE_COMMAND} #{BIN_DIR}/image_svc.js"}

  # used to obtain a copy of the Razor configuration
  def get_config
    resp = %x[#{BIN_DIR}/razor -j config]
    JSON.parse(resp)
  end

  # used to fire off a task (via a slice command) to the underlying Razor server
  # instance that checks the timing of long-running processes in the Razor server
  # (and that handles any that are found to have exceeded their defined time-outs).
  #
  # TODO; implement the RazorDaemon.check_task_timing method (and the slice it uses)
  def check_task_timing
    # no-op
  end

  # check the connection with the underlying database.  If no database can be found
  # (i.e. if a connection does not exist and cannot be established), then an error
  # will be thrown by this method.
  def check_database_connection
    resp = %x[#{BIN_DIR}/razor config dbcheck]
    raise RuntimeError.new("Database connection could not be established " +
                               "using the current server configuration; check configuration" +
                               "and database state") unless resp.strip == "true"
  end

  # used during the daemon's event-handling loop to verify that all of the nodes
  # listed (by name) in the 'NODE_INSTANCE_NAMES' array are still running.  If any
  # of the named node instances have failed (or were never started), this method
  # will (re)start those instances
  def ensure_nodes_running
    node_proc_info = get_node_instance_info
    # if there are existing node processes, only restart the nodes that aren't running;
    # else need to (re)start all of the node instances (because none are running)
    if node_proc_info.size > 0
      NODE_INSTANCE_NAMES.each { |node|
        unless node_proc_info.key?(node)
          puts "(Re)starting '#{node}' using command '#{NODE_COMMAND_MAP[node]}'"
          job = fork do
            exec NODE_COMMAND_MAP[node]
          end
          Process.detach(job)
        end
      }
    else
      NODE_INSTANCE_NAMES.each { |node|
        puts "(Re)starting '#{node}' using command '#{NODE_COMMAND_MAP[node]}'"
        job = fork do
          exec NODE_COMMAND_MAP[node]
        end
        Process.detach(job)
      }
    end
  end

  # used to remove nodes from the system that have not checked in recently
  # (here, recently means within the time period defined by the node_expire_timeout
  # that is defined in the configuration)
  def remove_expired_nodes(node_expire_timeout)
    engine = ProjectRazor::Engine.instance
    engine.remove_expired_nodes(node_expire_timeout)
  end

  # used to shut down all "node-related" processes in the system during
  # the process of shutting down this daemon
  def shutdown_node_instances
    puts "Shutting down node instances using command 'killall -2 node'"
    %x[killall -2 node]
  end

  private

  # returns the information about any "node-related" processes from the
  # system's process table
  def get_node_instance_info
    node_ps_out = %x[ps ax | grep node].split("\n")
    node_proc_info = {}
    node_ps_out.each { |line|
      fields = line.split
      NODE_INSTANCE_NAMES.each { |node_name|
        node_proc_info[node_name] = fields if (fields.count { |field|
          /bin\/#{node_name}$/.match(field)} > 0)
      }
    }
    node_proc_info
  end

end

# define the directory to use for logging
log_dir = bin_dir.sub(/\/bin$/,"/log")

# and define the directory that the daemon's "pid" file will be created in
razor_dir = bin_dir.sub(/\/bin$/,"")

# used to cleanly shut down the processes being managed by this daemon
# (i.e. the Node.js instances)
def shutdown_instances
  # clean up before exiting
  razor_daemon = RazorDaemon.instance
  razor_daemon.shutdown_node_instances
end

# used to get the minimum cycle time from the Razor server configuration
# (the one and only input argument to the function)
def get_min_cycle_time(razor_config)
  # get the value that should be used from the Razor server configuration
  min_cycle_time = razor_config['@daemon_min_cycle_time']
  # set to the default value if there was no value read from the configuration
  min_cycle_time = DEFAULT_MIN_CYCLE_TIME unless min_cycle_time
  # and return the result
  min_cycle_time
end

# used to get the node expiration timeout value from the Razor server
# configuration (returns the DEFAULT_NODE_EXPIRE_TIMEOUT if no parameter
# is set in the Razor server configuration...
def get_node_expire_timeout(razor_config)
  # get the value that should be used from the Razor server configuration
  node_expire_timeout = razor_config['@node_expire_timeout']
  # set to the default value if there was no value read from the configuration
  node_expire_timeout = DEFAULT_NODE_EXPIRE_TIMEOUT unless node_expire_timeout
  # and return the result
  node_expire_timeout
end

# define some options for our daemon process (below)
options = {
    :ontop      => false,
    :multiple => false,
    :log_dir  => log_dir,
    :log_output => true,
    :backtrace  => true,
    :dir_mode => :normal,
    :dir => razor_dir
}

# get a reference to the RazorDaemon singleton (defined above)
razor_daemon = RazorDaemon.instance

# using that singleton, obtain a copy of the Razor server configuration and,
# from that configuration, determine how long to sleep between passes through
# the daemon's event-handling loop (below).  Convert the "minimum cycle time"
# from that Razor server configuration to milliseconds (for calculation of the
# time remaining in each iteration).  This will ensure that the sleep time
# for each iteration will be accurate to the nearest millisecond.
razor_config = razor_daemon.get_config

# run an initial check of the MongoDB instance to ensure that it is accessible
# (if it is not, print out an error message and exit)
begin
  # check the connection with the underlying database (if a connection cannot be
  # established using the current server configuration, an error message is printed
  # out on the console and the script will exit (without starting the associated
  # daemon process)
  razor_daemon.check_database_connection
rescue RuntimeError => e
  puts "Cannot start the Razor Server; the database needed to run Razor is not"
  puts "accessible using the current Razor configuration:"
  puts "    persist_host:  #{razor_config['@persist_host']}"
  puts "    persist_port:  #{razor_config['@persist_port']}"
  puts "razor_daemon.rb is exiting now..."
  exit(-1)
end

# and start that daemon process
Daemons.run_proc("razor_daemon", options) {

  # used to clean up underlying processes on exit from the daemon process
  at_exit do
    shutdown_instances
  end

  # get a reference to the RazorDaemon singleton (defined above)
  razor_daemon = RazorDaemon.instance

  # using that singleton, obtain a copy of the Razor server configuration and,
  # from that configuration, determine how long to sleep between passes through
  # the daemon's event-handling loop (below).  Convert the "minimum cycle time"
  # from that Razor server configuration to milliseconds (for calculation of the
  # time remaining in each iteration).  This will ensure that the sleep time
  # for each iteration will be accurate to the nearest millisecond.
  razor_config = razor_daemon.get_config
  msecs_sleep = get_min_cycle_time(razor_config) * 1000;
  node_expire_timeout = get_node_expire_timeout(razor_config)

  # flag that is used to ensure razor_config is reloaded before each pass through
  # the event-handling loop, but not on the first pass (since we just loaded it)
  is_first_iteration = true

  # now that everything is configured properly, enter the main event-handling loop
  loop do

    begin

      # grab the current time (used for calculation of the wait time and for
      # determining whether or not to register the node if the facts have changed
      # later in the event-handling loop)
      t1 = Time.now

      # reload configuration from Razor if not the first time through the loop
      unless is_first_iteration
        razor_config = razor_daemon.get_config
        # adjust time to sleep it has changed since the last iteration
        msecs_sleep = get_min_cycle_time(razor_config) * 1000;
        node_expire_timeout = get_node_expire_timeout(razor_config)
      else
        is_first_iteration = false
      end

      # check the connection with the underlying database (if a connection cannot be
      # established using the current server configuration, an error is thrown by
      # this method and the daemon will exit (killing the underlying Razor server
      # processes as it does so).
      razor_daemon.check_database_connection

      # check that instances of critical services (Node.js and mongodb) are running
      razor_daemon.ensure_nodes_running

      # use the singleton to fire off an event to the Razor server (via a slice
      # command?) that checks the timings for tasks running in that server.
      razor_daemon.check_task_timing

      # remove "expired" nodes from the database (i.e. nodes that haven't
      # checked in during the past 'node_expire_timeout' seconds)
      razor_daemon.remove_expired_nodes(node_expire_timeout)

      # check to see how much time has elapsed, sleep for the time remaining
      # in the msecs_sleep time window
      t2 = Time.now
      msecs_elapsed = (t2 - t1) * 1000
      if msecs_elapsed < msecs_sleep then
        secs_sleep = (msecs_sleep - msecs_elapsed)/1000.0
        #puts "Sleeping for #{secs_sleep} secs..."
        sleep(secs_sleep) if secs_sleep >= 0.0
      end

    rescue RuntimeError => e

      puts e.message
      puts "Razor server exiting"
      exit(-1)

    rescue => e

      puts "An exception occurred: #{e.message}"
      # check to see how much time has elapsed, sleep for the time remaining
      # in the msecs_sleep time window (to avoid spinning through this loop
      # over and over again with no lag if an error is thrown within the
      # loop itself)
      t2 = Time.now
      msecs_elapsed = (t2 - t1) * 1000
      if msecs_elapsed < msecs_sleep then
        secs_sleep = (msecs_sleep - msecs_elapsed)/1000.0
        sleep(secs_sleep) if secs_sleep >= 0.0
      end

    end

  end

}
