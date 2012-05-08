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
        @hidden = false
        # Here we create a hash of the command string to the method it corresponds to for routing.
        @slice_commands = {:default => "get_model",
                           :get => "get_model",
                           :add => "add_model",
                           :remove => "remove_model"}
        @slice_commands_help = {:get => "razor model ".red + "{get [template]}".blue,
                                :default => "razor model ".red + "{get [template]}".blue,
                                :add_cli => "razor model add".red + " (model_template) (model name)".blue,
                                :add_cli_with_image => "razor model add".red + " (model_template) (model name) {image uuid}".blue,
                                :add_web => "razor model add".red + " (model_template) (json string)".blue,
                                :remove => "razor model remove".red + " (model uuid)".blue}
        @slice_name = "Model"
      end

      def get_model
        @command = :get
        @arg01 =  @command_array.shift

        case @arg01
          when "config"
            get_models
          when "template"
            get_model_templates
          when "help"
            slice_error("Help", false)
          else
            get_models
        end
      end


      def get_models
        print_object_array get_object("models", :model), "Models"
      end

      def get_model_templates
        policies = ProjectRazor::Policies.instance
        print_model_templates policies.get_model_templates
      end


      def remove_model
        @command = :remove
        model_uuid = @command_array.shift

        unless validate_arg(model_uuid)
          slice_error("MissingUUID")
          get_models
          return
        end

        setup_data
        model = @data.fetch_object_by_uuid(:model, model_uuid)

        unless models
          slice_error("CannotFindModelConfig")
          get_models
          return
        end

        if @data.delete_object(model)
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
        policies = ProjectRazor::Policies.instance

        unless @model_name != nil
          slice_error("Model Template Missing")
          return
        end


        new_model = policies.is_model_template?(@model_name)
        unless new_model
          slice_error("Model Template Missing")
          return
        end

        @model_label =  @command_array.shift
        unless @model_label != nil
          slice_error("Model Name Missing")
          return
        end

        new_model.label = @model_label


        if new_model.instance_variable_get(:@image_uuid)
          @command = :add_cli_with_image
          @model_image_uuid = @command_array.shift
          unless @model_image_uuid
            slice_error("ImageUUIDToBindMissing")
            valid_images = get_object("images", :images).map! do |i|
              i.path_prefix == new_model.image_prefix ? i : nil
            end.compact!
            if valid_images.count > 0
              print_images valid_images
            else
              puts "There are no valid images in the system. You must add one."
            end

            return
          end

          setup_data
          @image_requested = @data.fetch_object_by_uuid(:images, @model_image_uuid)
          unless @image_requested != nil
            slice_error("ImageDoesNotExist")
            valid_images = get_object("images", :images).map! do |i|
              i.path_prefix == new_model.image_prefix ? i : nil
            end.compact!
            if valid_images.count > 0
              print_images valid_images
            else
              puts "There are no valid images in the system. You must add one."
            end
            return
          end

          unless @image_requested.path_prefix == new_model.image_prefix
            slice_error("Image Is Not Correct Template")
            valid_images = get_object("images", :images).map! do |i|
              i.path_prefix == new_model.image_prefix ? i : nil
            end.compact!
            if valid_images.count > 0
              print_images valid_images
            else
              puts "There are no valid images in the system. You must add one."
            end
            return
          end

          new_model.image_uuid = @image_requested.uuid
        end


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
        @model_template =  @command_array.shift
        @values_json_string =  @command_array.shift
        slice_error("NotImplemented")
      end

      ####################


    end
  end
end