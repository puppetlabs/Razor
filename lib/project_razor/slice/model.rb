require 'json'

# Root ProjectRazor namespace
module ProjectRazor
  module Slice
    # ProjectRazor Slice Model
    class Model < ProjectRazor::Slice::Base
      include(ProjectRazor::Logging)
      # Initializes ProjectRazor::Slice::Model including #slice_commands, #slice_commands_help, & #slice_name
      # @param [Array] args
      def initialize(args)
        super(args)
        @hidden = false
        @new_slice_style = true
        @slice_commands = {:add => "add_model",
                           :get => {
                               :default => "get_all_models",
                               :else => "get_model_by_uuid",
                               :template => {
                                   ['{}'] => "get_all_templates",
                                   :default => "get_all_templates",
                                   :else => "get_all_templates"
                               },
                           },
                           :update => {
                               :default => "get_all_models",
                               :else => "update_model"
                           },
                           :remove => {
                               :default => "get_all_models",
                               :all => "remove_all_models",
                               :else => "remove_model"
                           },
                           :default => "get_all_models",
                           :else => :get,
                           :help => ""}
        @slice_name = "Model"
      end


      def get_all_models
        # Get all tag rules and print/return
        @command = :get_all_models
        @command_array.unshift(@last_arg) unless @last_arg == 'default'
        print_object_array get_object("models", :model), "Models", :style => :table, :success_type => :generic
      end

      def get_model_by_uuid
        @command = :get_model_by_uuid
        @command_help_text = "razor model [get] (uuid)"
        model = get_object("get_model_by_uuid", :model, @command_array.first)
        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Model with UUID: [#{@command_array.first}]" unless model
        print_object_array [model] ,"",:success_type => :generic
      end

      def get_all_templates
        # We use the common method in Utility to fetch object templates by providing Namespace prefix
        print_object_array get_child_templates(ProjectRazor::ModelTemplate), "Model Templates:"
      end

      def add_model
        @command =:add_model
        options = {}
        option_items = load_option_items(:command => :add)
        # Get our optparse object passing our options hash, option_items hash, and our banner
        optparse     = get_options(options, :options_items => option_items, :banner => "razor model add [options...]", :list_required => true)
        # set the command help text to the string output from optparse
        @command_help_text << optparse.to_s
        # if it is a web command, get options from JSON
        options = get_options_web if @web_command
        # parse our ARGV with the optparse unless options are already set from get_options_web
        optparse.parse! unless option_items.any? { |k| options[k] }
        # validate required options
        validate_options(:option_items => option_items, :options => options, :logic => :require_all)

        template   = options[:template]
        image_uuid = options[:image_uuid]
        label      = options[:label]

        model = verify_template(template)
        raise ProjectRazor::Error::Slice::InvalidModelTemplate, "Invalid Model Template [#{template}] " unless model
        image = model.image_prefix ? verify_image(model, image_uuid) : true
        raise ProjectRazor::Error::Slice::InvalidUUID, "Invalid Image UUID [#{image_uuid}] " unless image
        if @web_command
          raise ProjectRazor::Error::Slice::MissingArgument, "Must Provide Required Metadata [--req_metadata_hash]" unless
              req_metadata_hash
          model.web_create_metadata(req_metadata_hash)
        else
          raise ProjectRazor::Error::Slice::UserCancelled, "User cancelled Model creation" unless model.cli_create_metadata
        end
        model.label = label
        model.image_uuid = image.uuid
        model.is_template = false
        setup_data
        @data.persist_object(model)
        model ? print_object_array([model], "Model created", :success_type => :created) : raise(ProjectRazor::Error::Slice::CouldNotCreate, "Could not create Model")
      end

      def verify_template(template_name)
        get_child_templates(ProjectRazor::ModelTemplate).each { |template| return template if template.name == template_name }
        nil
      end

      def verify_image(model, image_uuid)
        setup_data
        image = get_object("find_image", :images, image_uuid)
        if image
          return image if model.image_prefix == image.path_prefix
        end
        nil
      end

      def update_model
        @command = :update_model
        options = {}
        option_items = load_option_items(:command => :update)
        # Get our optparse object passing our options hash, option_items hash, and our banner
        optparse     = get_options(options, :options_items => option_items, :banner => "razor model update [options...]", :list_required => true)
        # set the command help text to the string output from optparse
        @command_help_text << optparse.to_s
        # if it is a web command, get options from JSON
        options = get_options_web if @web_command
        # parse our ARGV with the optparse unless options are already set from get_options_web
        optparse.parse! unless option_items.any? { |k| options[k] }
        # validate required options
        validate_options(:option_items => option_items, :options => options, :logic => :require_all)

        model_uuid = options[:model_uuid]
        model = get_object("model_with_uuid", :model, model_uuid).first
        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Model with UUID: [#{model_uuid}]" unless model
        label      = options[:label]
        image_uuid = options[:image_uuid]
        req_metadata_hash = options[:req_metadata_hash]
        change_metadata   = options[:change_metadata]

        label, image_uuid, req_metadata_hash = *get_web_vars(%w(--label --image-uuid --req-metadata_hash)) if @web_command
        label, image_uuid, change_metadata = *get_cli_vars(%w(--label --image-uuid --change-metadata)) unless label || image_uuid || change_metadata
        raise ProjectRazor::Error::Slice::MissingArgument, "Must provide at least one value to update" unless label || image_uuid || change_metadata
        if @web_command
          if req_metadata_hash
            model.web_create_metadata(req_metadata_hash)
          end
        else
          if change_metadata
            raise ProjectRazor::Error::Slice::UserCancelled, "User cancelled Model creation" unless
                model.cli_create_metadata
          end
        end
        model.label = label if label
        image = model.image_prefix ? verify_image(model, image_uuid) : true if image_uuid
        raise ProjectRazor::Error::Slice::InvalidUUID, "Invalid Image UUID [#{image_uuid}] " unless image || !image_uuid
        model.image_uuid = image.uuid if image
        raise ProjectRazor::Error::Slice::CouldNotUpdate, "Could not update Model [#{model.uuid}]" unless model.update_self
        print_object_array [model] ,"",:success_type => :updated
      end

      def remove_all_models
        @command = :remove_all_models
        @command_help_text = "razor model remove all"
        raise ProjectRazor::Error::Slice::CouldNotRemove, "Could not remove all Tag Rules" unless @data.delete_all_objects(:model)
        slice_success("All Models removed",:success_type => :removed)
      end

      def remove_model
        @command = :remove_model
        @command_help_text = "razor model remove (UUID)"
        model_uuid = @command_array.shift
        model = get_object("model_with_uuid", :model, model_uuid)
        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Model with UUID: [#{model_uuid}]" unless model
        setup_data
        raise ProjectRazor::Error::Slice::CouldNotRemove, "Could not remove Model [#{tagrule.uuid}]" unless @data.delete_object(model)
        slice_success("Active Model [#{model.uuid}] removed",:success_type => :removed)
      end

    end
  end
end
