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
                                   :default => "get_all_templates",
                                   :else => "get_template_by_name"
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
        @command_help_text = "razor model add template=(model template) label=(model label) {image_uuid=(Image UUID)}\n"
        @command_help_text << "\t template: \t" + " The Model Template name to use\n".yellow
        @command_help_text << "\t label: \t" + " A label to name this Model\n".yellow
        @command_help_text << "\t image_uuid: \t" + " If the Model Template requires an Image, the Image UUID\n".yellow
        template, label, image_uuid, req_metadata_hash =
            *get_web_vars(%w(template label image_uuid req_metadata_hash)) if @web_command
        template, label, image_uuid =
            *get_cli_vars(%w(template label image_uuid)) unless template || label || image_uuid
        # Validate our args are here
        raise ProjectRazor::Error::Slice::MissingArgument, "Must Provide A Model Template [template]" unless validate_arg(template)
        raise ProjectRazor::Error::Slice::MissingArgument, "Must Provide A Model Label [label]" unless validate_arg(label)
        raise ProjectRazor::Error::Slice::MissingArgument, "Must Provide A Image UUID [image_uuid]" unless validate_arg(image_uuid)
        model = verify_template(template)
        raise ProjectRazor::Error::Slice::InvalidModelTemplate, "Invalid Model Template [#{template}] " unless model
        image = model.image_prefix ? verify_image(model, image_uuid) : true
        raise ProjectRazor::Error::Slice::InvalidUUID, "Invalid Image UUID [#{image_uuid}] " unless image
        if @web_command
          raise ProjectRazor::Error::Slice::MissingArgument, "Must Provide A Model Template [template]" unless
              validate_arg(req_metadata_hash)
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
        @command_help_text = "razor model update (model uuid) {label=(Model Label)} {image_uuid=(Image UUID)} {change_metadata=true}\n"
        @command_help_text << "\t label: \t\t" + " A label to name this Model\n".yellow
        @command_help_text << "\t image_uuid: \t\t" + " If the Model Template requires an Image, the Image UUID\n".yellow
        @command_help_text << "\t change_metadata: \t" + " Triggers changing the Model metadata\n".yellow
        model_uuid = @command_array.shift
        model = get_object("model_with_uuid", :model, model_uuid)
        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Model with UUID: [#{model_uuid}]" unless model
        label, image_uuid, req_metadata_hash = *get_web_vars(%w(label image_uuid req_metadata_hash)) if @web_command
        label, image_uuid, change_metadata = *get_cli_vars(%w(label image_uuid change_metadata)) unless label || image_uuid || change_metadata
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
        p model.label
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
