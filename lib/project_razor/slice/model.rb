require 'json'

# Root ProjectRazor namespace
module ProjectRazor
  class Slice
    # ProjectRazor Slice Model
    class Model < ProjectRazor::Slice
      include(ProjectRazor::Logging)
      # Initializes ProjectRazor::Slice::Model including #slice_commands, #slice_commands_help, & #slice_name
      # @param [Array] args
      def initialize(args)
        super(args)
        @hidden = false
        @slice_name = "Model"
        # get the slice commands map for this slice (based on the set
        # of commands that are typical for most slices)
        @slice_commands = get_command_map("model_help",
                                          "get_all_models",
                                          "get_model_by_uuid",
                                          "add_model",
                                          "update_model",
                                          "remove_all_models",
                                          "remove_model_by_uuid")
        # and add any additional commands specific to this slice
        @slice_commands[:get].delete(/^(?!^(all|\-\-help|\-h|\{\}|\{.*\}|nil)$)\S+$/)
        @slice_commands[:get][:else] = "get_model_by_uuid"
        @slice_commands[:get][[/^(temp|template|templates|types)$/]] = "get_all_templates"
      end

      def model_help
        if @prev_args.length > 1
          command = @prev_args.peek(1)
          begin
            # load the option items for this command (if they exist) and print them
            option_items = load_option_items(:command => command.to_sym)
            print_command_help(@slice_name.downcase, command, option_items)
            return
          rescue
          end
        end
        # if here, then either there are no specific options for the current command or we've
        # been asked for generic help, so provide generic help
        puts get_model_help
      end

      def get_model_help
        return ["Model Slice: used to add, view, update, and remove models.".red,
                "Model Commands:".yellow,
                "\trazor model [get] [all]                 " + "View all models".yellow,
                "\trazor model [get] (UUID)                " + "View specific model instance".yellow,
                "\trazor model add (options...)            " + "Create a new model instance".yellow,
                "\trazor model update (UUID) (options...)  " + "Update a specific model instance".yellow,
                "\trazor model remove (UUID)|all           " + "Remove existing model(s)".yellow,
                "\trazor model --help                      " + "Display this screen".yellow].join("\n")
      end

      def get_all_models
        @command = :get_all_models
        # if it's a web command and the last argument wasn't the string "default" or "get", then a
        # filter expression was included as part of the web command
        @command_array.unshift(@prev_args.pop) if @web_command && @prev_args.peek(0) != "default" && @prev_args.peek(0) != "get"
        # Get all tag rules and print/return
        print_object_array get_object("models", :model), "Models", :style => :table, :success_type => :generic
      end

      def get_model_by_uuid
        @command = :get_model_by_uuid
        # the UUID is the first element of the @command_array
        model_uuid = @command_array.first
        model = get_object("get_model_by_uuid", :model, model_uuid)
        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Model with UUID: [#{model_uuid}]" unless model && (model.class != Array || model.length > 0)
        print_object_array [model] ,"",:success_type => :generic
      end

      def get_all_templates
        @command = :get_all_templates
        if @web_command && @prev_args.peek(0) != "templates"
          not_found_error = "(use of aliases not supported via REST; use '/model/templates' not '/model/#{@prev_args.peek(0)}')"
          raise ProjectRazor::Error::Slice::NotFound, not_found_error
        end
        # We use the common method in Utility to fetch object templates by providing Namespace prefix
        print_object_array get_child_templates(ProjectRazor::ModelTemplate), "Model Templates:"
      end

      def add_model
        @command = :add_model
        includes_uuid = false
        # load the appropriate option items for the subcommand we are handling
        option_items = load_option_items(:command => :add)
        # parse and validate the options that were passed in as part of this
        # subcommand (this method will return a UUID value, if present, and the
        # options map constructed from the @commmand_array)
        tmp, options = parse_and_validate_options(option_items, "razor model add (options...)", :require_all)
        includes_uuid = true if tmp && tmp != "add"
        # check for usage errors (the boolean value at the end of this method
        # call is used to indicate whether the choice of options from the
        # option_items hash must be an exclusive choice)
        check_option_usage(option_items, options, includes_uuid, false)
        template = options[:template]
        label = options[:label]
        image_uuid = options[:image_uuid]
        req_metadata_hash = options[:req_metadata_hash] if @web_command
        # check the values that were passed in
        model = verify_template(template)
        raise ProjectRazor::Error::Slice::InvalidModelTemplate, "Invalid Model Template [#{template}] " unless model
        image = model.image_prefix ? verify_image(model, image_uuid) : true
        raise ProjectRazor::Error::Slice::InvalidUUID, "Invalid Image UUID [#{image_uuid}] " unless image
        # use the arguments passed in (above) to create a new model
        if @web_command
          raise ProjectRazor::Error::Slice::MissingArgument, "Must Provide Required Metadata [req_metadata_hash]" unless
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

      def update_model
        @command = :update_model
        includes_uuid = false
        # load the appropriate option items for the subcommand we are handling
        option_items = load_option_items(:command => :update)
        # parse and validate the options that were passed in as part of this
        # subcommand (this method will return a UUID value, if present, and the
        # options map constructed from the @commmand_array)
        model_uuid, options = nil, nil
        if @web_command
          model_uuid, options = parse_and_validate_options(option_items, "razor model update UUID (options...)", :require_none)
        else
          model_uuid, options = parse_and_validate_options(option_items, "razor model update UUID (options...)", :require_one)
        end

        includes_uuid = true if model_uuid
        # the :req_metadata_hash is not a valid value via the CLI but might be
        # included as part of a web command; as such the parse_and_validate_options
        # can't properly handle this error and we have to check here to ensure that
        # at least one value was provided in the update command
        if @web_command && options.all?{ |x| x == nil }
          option_names = option_items.map { |val| val[:name] }
          option_names.delete(:change_metadata)
          option_names << :req_metadata_hash
          raise ProjectRazor::Error::Slice::MissingArgument, "Must provide one option from #{option_names.inspect}."
        end
        # check for usage errors (the boolean value at the end of this method
        # call is used to indicate whether the choice of options from the
        # option_items hash must be an exclusive choice)
        check_option_usage(option_items, options, includes_uuid, false)
        label = options[:label]
        image_uuid = options[:image_uuid]
        change_metadata = options[:change_metadata]
        req_metadata_hash = options[:req_metadata_hash] if @web_command

        # check the values that were passed in (and gather new meta-data if
        # the --change-metadata flag was included in the update command and the
        # command was invoked via the CLI...it's an error to use this flag via
        # the RESTful API, the req_metadata_hash should be used instead)
        model = get_object("model_with_uuid", :model, model_uuid)
        raise ProjectRazor::Error::Slice::InvalidUUID, "Invalid Model UUID [#{model_uuid}]" unless model && (model.class != Array || model.length > 0)
        if @web_command
          if change_metadata
            raise ProjectRazor::Error::Slice::InputError, "Cannot use the change_metadata flag with a web command"
          elsif req_metadata_hash
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
        raise ProjectRazor::Error::Slice::MethodNotAllowed, "Cannot remove all Models via REST" if @web_command
        raise ProjectRazor::Error::Slice::CouldNotRemove, "Could not remove all Tag Rules" unless @data.delete_all_objects(:model)
        slice_success("All Models removed",:success_type => :removed)
      end

      def remove_model_by_uuid
        @command = :remove_model_by_uuid
        # the UUID was the last "previous argument"
        model_uuid = get_uuid_from_prev_args
        model = get_object("model_with_uuid", :model, model_uuid)
        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Model with UUID: [#{model_uuid}]" unless model && (model.class != Array || model.length > 0)
        setup_data
        raise ProjectRazor::Error::Slice::CouldNotRemove, "Could not remove Model [#{model.uuid}]" unless @data.delete_object(model)
        slice_success("Active Model [#{model.uuid}] removed",:success_type => :removed)
      end

      def verify_template(template_name)
        get_child_templates(ProjectRazor::ModelTemplate).each { |template| return template if template.name == template_name }
        nil
      end

      def verify_image(model, image_uuid)
        setup_data
        image = get_object("find_image", :images, image_uuid)
        if image && (image.class != Array || image.length > 0)
          return image if model.image_prefix == image.path_prefix
        end
        nil
      end

    end
  end
end
