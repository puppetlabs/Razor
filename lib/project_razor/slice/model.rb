# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved

require "json"
require "yaml"

# Root ProjectRazor namespace
# @author Nicholas Weaver
module ProjectRazor
  module Slice
    # ProjectRazor Slice Model
    # @author Nicholas Weaver
    class Model < ProjectRazor::Slice::Base
      include(ProjectRazor::Logging)
      # Initializes ProjectRazor::Slice::Model including #slice_commands, #slice_commands_help, & #slice_name
      # @param [Array] args
      def initialize(args)
        super(args)
        # Here we create a hash of the command string to the method it corresponds to for routing.
        @slice_commands = {:default => "get_model",
                           :get => "get_model",
                           :add => "add_model",
                           :remove => "remove_model"}
        @slice_commands_help = {:get => "imagesvc model ".red + "{get [config|type]}".blue,
                                :default => "imagesvc model ".red + "{get [config|type]}".blue,
                                :add_cli => "imagesvc model add".red + " (model_type) (model config name)".blue,
                                :add_web => "imagesvc model add".red + " (model_type) (json string)".blue,
                                :remove => "imagesvc model remove".red + " (model config uuid)".blue}
        @slice_name = "Model"
      end

      def get_model
        @command = :get
        @arg01 =  @command_array.shift

        case @arg01
          when "config"
            get_model_config
          when "type"
            get_model_types
          when "help"
            slice_error("Help", false)
          else
            get_model_config
        end
      end


      def get_model_config
        print_model_configs get_object("model_config", :model)
      end

      def get_model_types
        policy_rules = ProjectRazor::PolicyRules.instance
        print_model_types policy_rules.get_model_types
      end


      def remove_model
        @command = :remove
        model_uuid = @command_array.shift

        unless validate_arg(model_uuid)
          slice_error("MissingUUID")
          return
        end

        setup_data
        model_config = @data.fetch_object_by_uuid(:model, model_uuid)

        unless model_config
          slice_error("CannotFindModelConfig")
          get_model_config
          return
        end

        if @data.delete_object(model_config)
          slice_success("ModelConfigRemoved")
        else
          slice_error("ModelConfigNotRemoved")
        end
      end

      def add_model
        if @web_command
          # REST call
          add_model_web
        else
          # CLI call
          add_model_cli
        end
      end

      ##### CLI Add Model

      def add_model_cli
        @command = :add_cli
        @model_name =  @command_array.shift
        policy_rules = ProjectRazor::PolicyRules.instance

        unless @model_name != nil
          slice_error("ModelTypeMissing")
          return
        end


        new_model = policy_rules.is_model_type?(@model_name)
        unless new_model
          slice_error("ModelTypeNotFound")
          return
        end

        @model_label =  @command_array.shift
        unless @model_label != nil
          slice_error("ModelNameMissing")
          return
        end

        new_model.label = @model_label
        if new_model.req_metadata_hash != {}
          if cli_interactive_metadata(new_model) != nil
            insert_model_config(new_model)
          else
            return
          end
        else
          insert_model_config(new_model)
        end
      end

      def insert_model_config(new_model)
        setup_data
        new_model = @data.persist_object(new_model)
        if new_model.refresh_self
          print_model_configs [new_model]
        else
          slice_error("CouldNotSaveModelConfig")
        end
      end

      def cli_interactive_metadata(new_model)
        req_metadata_hash = new_model.req_metadata_hash
        puts "\n--- Building Model Config(#{@model_name}): #{@model_config_name}\n".yellow
        req_metadata_hash.each_key do
        |md|
          flag = false
          default = req_metadata_hash[md][:default]
          validation = req_metadata_hash[md][:validation]
          required = req_metadata_hash[md][:required]
          description = req_metadata_hash[md][:description]
          example = req_metadata_hash[md][:example]
          until flag

            response = @command_array.shift

            if response == nil
              print "\nPlease enter " + "#{description}".yellow.bold
              print " (example: " + "#{example}}".yellow + ") \n"
              if default != ""
                puts "default: " + "#{default}".yellow
              end
              if required
                puts quit_option
              else
                puts skip_quit_option
              end
              print " > "
              response = gets.strip
            end

            case response
              when "SKIP"
                if required
                  puts "Cannot skip, value required".red
                else
                  flag = true
                end
              when "QUIT"
                slice_error("AddCanceled")
                return nil
              when ""
                if default != ""
                  flag = set_metadata_value(new_model, md, default, validation)
                else
                  puts "no default value, must enter something".red
                end
              else
                flag = set_metadata_value(new_model, md, response, validation)
            end
          end
        end
        new_model
      end

      def set_metadata_value(new_model, key, value, validation)
        regex = Regexp.new(validation)
        if regex =~ value
          new_model.instance_variable_set(key.to_sym, value)
          true
        else
          puts "Value (".red + "#{value}".yellow + ") is invalid".red
          false
        end
      end

      def skip_quit_option
        "(" + "SKIP".white + " to skip, " + "QUIT".red + " to cancel)"
      end

      def quit_option
        "(" + "QUIT".red + " to cancel)"
      end

      def add_model_web
        @command = :add_web
        @model_type =  @command_array.shift
        @values_json_string =  @command_array.shift
        slice_error("NotImplemented")
      end

      ####################


    end
  end
end