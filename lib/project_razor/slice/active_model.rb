require "json"


# Root ProjectRazor namespace
module ProjectRazor
  module Slice

    # ProjectRazor Slice Active_Model
    class Active_model < ProjectRazor::Slice::Base
      def initialize(args)
        super(args)
        @hidden          = false
        @new_slice_style = true
        @slice_commands  = {
            :get                           => { ["all", '{}', /^\{.*\}$/, nil, /^[Aa]$/]                   => "get_active_model_all",
                                                :default                                                   => "get_active_model_all",
                                                :else                                                      => "get_active_model_by_uuid",
            },
            :default                       => "get_active_model_all",
            :logview                       => "get_logview",
            :remove                        => { :all                                     => "remove_active_model_all",
                                                :default                                 => "remove_active_model_by_uuid",
                                                :else                                    => "remove_active_model_by_uuid"},
            :else                          => :get,
            ["help","--help","-h"]                          => "active_model_help" }
        @slice_name      = "Active_model"
        @policies        = ProjectRazor::Policies.instance
      end

      def active_model_help
        puts "Active Model Slice:".red
        puts "Used to view active models, active model logs, and remove active models.".red
        puts "Policy commands:".yellow
        puts "\trazor active_model                                     " + "View all active models".yellow
        puts "\trazor active_model (active model uuid) [options...]    " + "View specific active model".yellow
        puts "\trazor active_model logview                             " + "Prints an aggregate active model log view".yellow
        puts "\trazor active_model remove (active model uuid)|all      " + "Remove an existing active model(s)".yellow
        puts "\trazor active_model help                                " + "Display this screen".yellow
      end

      def get_active_model_all
        # Get all active model instances and print/return
        @command_array.unshift(@last_arg) unless @last_arg == 'default'
        print_object_array get_object("active_models", :active), "Active Models:", :success_type => :generic, :style => :table
      end

      def get_active_model_by_uuid
        @command     =:get_active_model_all
        raise ProjectRazor::Error::Slice::MissingArgument, "Must Provide An Active Model UUID" unless validate_arg(@command_array.first)
        active_model = get_object("active_model_instance", :active, @command_array.first)
        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Active Model with UUID: [#{@command_array.first}]" unless active_model
        options      = {}
        option_items = load_option_items(:command => :get_active_model)
        optparse     = get_options(options, :options_items => option_items, :banner => "razor active_model [options...]", :list_required => true)
        @command_help_text << optparse.to_s
        options = get_options_web if @web_command
        optparse.parse! unless option_items.any? { |k| options[k] }
        # validate required options
        validate_options(:option_items => option_items, :options => options, :logic => :require_all)
        unless options[:logs]
          print_object_array [active_model], "", :success_type => :generic
        else
          print_object_array [active_model], "", :success_type => :generic, :style => :table
          print_object_array(active_model.print_log, "", :style => :table)
        end
      end

      def remove_active_model_all
        @command           = :remove_active_model_all
        @command_help_text = "razor active_model remove all"
        raise ProjectRazor::Error::Slice::CouldNotRemove, "Could not remove all Active Models" unless get_data.delete_all_objects(:active)
        slice_success("All active models removed", :success_type => :removed)
      end

      def remove_active_model_by_uuid
        @command     =:remove_active_model_by_uuid
        raise ProjectRazor::Error::Slice::MissingArgument, "Must Provide An Active Model UUID" unless validate_arg(@command_array.first)
        active_model = get_object("active_model_instance", :active, @command_array.first)
        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Active Model with UUID: [#{@command_array.first}]" unless active_model
        raise ProjectRazor::Error::Slice::CouldNotRemove, "Could not remove Active Model [#{active_model_uuid}]" unless get_data.delete_object(active_model)
        slice_success("Active model #{active_model.uuid} removed", :success_type => :removed)
      end

      def get_logview
        @command      = :get_active_log_all
        active_models = get_object("active_models", :active)
        log_items     = []
        active_models.each { |bp| log_items = log_items | bp.print_log_all }
        log_items.sort! { |a, b| a.print_items[3] <=> b.print_items[3] }
        log_items.each { |li| li.print_items[3] = Time.at(li.print_items[3]).strftime("%H:%M:%S") }
        print_object_array(log_items, "All Active Model Logs:", :success_type => :generic, :style => :table)
      end

    end
  end
end


