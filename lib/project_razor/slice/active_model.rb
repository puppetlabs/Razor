require "json"


# Root ProjectRazor namespace
module ProjectRazor
  class Slice

    # ProjectRazor Slice Active_Model
    class ActiveModel < ProjectRazor::Slice
      def initialize(args)
        super(args)
        @hidden          = false
        @policies        = ProjectRazor::Policies.instance
      end

      def slice_commands
        # get the slice commands map for this slice (based on the set of
        # commands that are typical for most slices)
        commands = get_command_map(
          "active_model_help",
          "get_all_active_models",
          "get_active_model_by_uuid",
          nil,
          nil,
          "remove_all_active_models",
          "remove_active_model_by_uuid")

        commands[:logview] = "get_logview"
        commands[:get][/^(?!^(all|\-\-help|\-h|\{\}|\{.*\}|nil)$)\S+$/][:logs] = "get_active_model_logs"

        commands
      end

      def active_model_help
        if @prev_args.length > 1
          command = @prev_args.peek(1)
          begin
            # load the option items for this command (if they exist) and print them
            option_items = load_option_items(:command => command.to_sym)
            print_command_help(command, option_items)
            return
          rescue
          end
        end
        # if here, then either there are no specific options for the current command or we've
        # been asked for generic help, so provide generic help
        puts "Active Model Slice: used to view active models or active model logs, and to remove active models.".red
        puts "Active Model Commands:".yellow
        puts "\trazor active_model [get] [all]          " + "View all active models".yellow
        puts "\trazor active_model [get] (UUID) [logs]  " + "View specific active model (log)".yellow
        puts "\trazor active_model logview              " + "Prints an aggregate active model log view".yellow
        puts "\trazor active_model remove (UUID)|all    " + "Remove existing (or all) active model(s)".yellow
        puts "\trazor active_model --help|-h            " + "Display this screen".yellow
      end

      def get_all_active_models
        @command = :get_all_active_models
        # if it's a web command and the last argument wasn't the string "default" or "get", then a
        # filter expression was included as part of the web command
        @command_array.unshift(@prev_args.pop) if @web_command && @prev_args.peek(0) != "default" && @prev_args.peek(0) != "get"
        # Get all active model instances and print/return
        print_object_array get_object("active_models", :active), "Active Models:", :success_type => :generic, :style => :table
      end

      def get_active_model_by_uuid
        @command = :get_active_model_by_uuid
        # the UUID is the first element of the @command_array
        uuid = get_uuid_from_prev_args
        active_model = get_object("active_model_instance", :active, uuid)
        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Active Model with UUID: [#{uuid}]" unless active_model && (active_model.class != Array || active_model.length > 0)
        print_object_array [active_model], "", :success_type => :generic
      end

      def get_active_model_logs
        @command = :get_active_model_logs
        raise ProjectRazor::Error::Slice::MethodNotAllowed, "Cannot view Active Model logs via REST" if @web_command
        # the UUID is the first element of the @command_array
        uuid = @prev_args.peek(1)
        active_model = get_object("active_model_instance", :active, uuid)
        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Active Model with UUID: [#{uuid}]" unless active_model && (active_model.class != Array || active_model.length > 0)
        #print_object_array [active_model], "", :success_type => :generic, :style => :table
        print_object_array active_model.print_log, "", :style => :table
      end

      def remove_all_active_models
        raise ProjectRazor::Error::Slice::MethodNotAllowed, "Cannot remove all Active Models via REST" if @web_command
        raise ProjectRazor::Error::Slice::CouldNotRemove, "Could not remove all Active Models" unless get_data.delete_all_objects(:active)
        slice_success("All active models removed", :success_type => :removed)
      end

      def remove_active_model_by_uuid
        @command = :remove_active_model_by_uuid
        # the UUID is the first element of the @command_array
        uuid = get_uuid_from_prev_args
        active_model = get_object("active_model_instance", :active, uuid)
        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Active Model with UUID: [#{uuid}]" unless active_model && (active_model.class != Array || active_model.length > 0)
        raise ProjectRazor::Error::Slice::CouldNotRemove, "Could not remove Active Model [#{active_model.uuid}]" unless get_data.delete_object(active_model)
        slice_success("Active model #{active_model.uuid} removed", :success_type => :removed)
      end

      def get_logview
        @command = :get_logview
        raise ProjectRazor::Error::Slice::MethodNotAllowed, "Cannot view Active Model logs via REST" if @web_command
        active_models = get_object("active_models", :active)
        log_items = []
        active_models.each { |bp| log_items = log_items | bp.print_log_all }
        log_items.sort! { |a, b| a.print_items[3] <=> b.print_items[3] }
        log_items.each { |li| li.print_items[3] = Time.at(li.print_items[3]).strftime("%H:%M:%S") }
        print_object_array(log_items, "All Active Model Logs:", :success_type => :generic, :style => :table)
      end

    end
  end
end


