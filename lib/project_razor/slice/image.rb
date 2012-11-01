require "json"
require "yaml"

# Root ProjectRazor namespace
module ProjectRazor
  class Slice

    # TODO - add inspection to prevent duplicate MK's with identical version to be added

    # ProjectRazor Slice Image
    # Used for image management
    class Image < ProjectRazor::Slice

      # Initializes ProjectRazor::Slice::Model including #slice_commands, #slice_commands_help, & #slice_name
      # @param [Array] args
      def initialize(args)
        super(args)
        @hidden = false
        @slice_name = "Image"

        # get the slice commands map for this slice (based on the set
        # of commands that are typical for most slices)
        @slice_commands = get_command_map(
          "image_help",
          "get_images",
          "get_image_by_uuid",
          "add_image",
          nil,
          nil,
          "remove_image")
      end

      def image_help
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
        puts "Image Slice: used to add, view, and remove Images.".red
        puts "Image Commands:".yellow
        puts "\trazor image [get] [all]         " + "View all images (detailed list)".yellow
        puts "\trazor image [get] (UUID)        " + "View details of specified image".yellow
        puts "\trazor image add (options...)    " + "Add a new image to the system".yellow
        puts "\trazor image remove (UUID)       " + "Remove existing image from the system".yellow
        puts "\trazor image --help|-h           " + "Display this screen".yellow
      end

      def get_types
        @image_types = get_child_types("ProjectRazor::ImageService::")
        @image_types.map {|x| x.path_prefix unless x.hidden}.compact.join("|")
      end

      #Lists details for all images
      def get_images
        @command = :get_images
        raise ProjectRazor::Error::Slice::NotImplemented, "accessible via cli only" if @web_command
        print_object_array(get_object("images", :images), "Images", :success_type => :generic, :style => :item)
      end

      #Lists details for a specific image
      def get_image_by_uuid
        @command = :get_image_by_uuid
        raise ProjectRazor::Error::Slice::NotImplemented, "accessible via cli only" if @web_command
        image_uuid = get_uuid_from_prev_args
        image = get_object("images", :images, image_uuid)
        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Image with UUID: [#{image_uuid}]" unless image && (image.class != Array || image.length > 0)
        print_object_array [image], "", :success_type => :generic
      end

      #Add an image
      def add_image
        @command = :add_image
        # raise an error if attempt is made to invoke this command via the web interface
        raise ProjectRazor::Error::Slice::NotImplemented, "accessible via cli only" if @web_command
        # define the available image types (input type must match one of these)
        image_types = {:mk => {:desc => "MicroKernel ISO",
                               :classname => "ProjectRazor::ImageService::MicroKernel",
                               :method => "add_mk"},
                       :os => {:desc => "OS Install ISO",
                               :classname => "ProjectRazor::ImageService::OSInstall",
                               :method => "add_os"},
                       :esxi => {:desc => "VMware Hypervisor ISO",
                                 :classname => "ProjectRazor::ImageService::VMwareHypervisor",
                                 :method => "add_esxi"}}

        includes_uuid = false
        # load the appropriate option items for the subcommand we are handling
        option_items = load_option_items(:command => :add)
        # parse and validate the options that were passed in as part of this
        # subcommand (this method will return a UUID value, if present, and the
        # options map constructed from the @commmand_array)
        tmp, options = parse_and_validate_options(option_items, "razor image add (options...)", :require_all)
        includes_uuid = true if tmp && tmp != "add"
        # check for usage errors (the boolean value at the end of this method
        # call is used to indicate whether the choice of options from the
        # option_items hash must be an exclusive choice)
        check_option_usage(option_items, options, includes_uuid, false)
        image_type = options[:type]
        iso_path = options[:path]
        os_name = options[:name]
        os_version = options[:version]

        unless ([image_type.to_sym] - image_types.keys).size == 0
          print_types(image_types)
          raise ProjectRazor::Error::Slice::InvalidImageType, image_type
        end

        raise ProjectRazor::Error::Slice::MissingArgument, '[/path/to/iso]' unless iso_path != nil && iso_path != ""

        classname = image_types[image_type.to_sym][:classname]
        new_image = ::Object::full_const_get(classname).new({})

        # We send the new image object to the appropriate method
        res = []
        unless image_type == "os"
          res = self.send image_types[image_type.to_sym][:method], new_image, iso_path,
                          @data.config.image_svc_path
        else
          res = self.send image_types[image_type.to_sym][:method], new_image, iso_path,
                          @data.config.image_svc_path, os_name, os_version
        end

        raise ProjectRazor::Error::Slice::InternalError, res[1] unless res[0]

        raise ProjectRazor::Error::Slice::InternalError, "Could not save image." unless insert_image(new_image)

        puts "\nNew image added successfully\n".green
        print_object_array([new_image], "Added Image:", :success_type => :created)
      end

      def add_mk(new_image, iso_path, image_svc_path)
        puts "Attempting to add, please wait...".green
        new_image.add(iso_path, image_svc_path, nil)
      end

      def add_esxi(new_image, iso_path, image_svc_path)
        puts "Attempting to add, please wait...".green
        new_image.add(iso_path, image_svc_path, nil)
      end

      def add_os(new_image, iso_path, image_svc_path, os_name, os_version)
        raise ProjectRazor::Error::Slice::MissingArgument,
              'image name must be included for OS images' unless os_name && os_name != ""
        raise ProjectRazor::Error::Slice::MissingArgument,
              'image version must be included for OS images' unless os_version && os_version != ""
        puts "Attempting to add, please wait...".green
        new_image.add(iso_path, image_svc_path, {:os_version => os_version, :os_name => os_name})
      end

      def insert_image(image_obj)
        setup_data
        image_obj = @data.persist_object(image_obj)
        image_obj.refresh_self
      end

      def print_types(types)

        unless @image_types
          get_types
        end

        puts "\nPlease select a valid image type.\nValid types are:".red
        @image_types.map {|x| x unless x.hidden}.compact.each do
        |type|
          print "\t[#{type.path_prefix}]".yellow
          print " - "
          print "#{type.description}".yellow
          print "\n"
        end
      end

      def remove_image
        @command = :remove_image
        # the UUID is the first element of the @command_array
        image_uuid = get_uuid_from_prev_args
        raise ProjectRazor::Error::Slice::MissingArgument, '[uuid]' unless image_uuid

        #setup_data
        #image_selected = @data.fetch_object_by_uuid(:images, image_uuid)
        image_selected = get_object("image_with_uuid", :images, image_uuid)
        raise ProjectRazor::Error::Slice::InvalidUUID unless image_selected && (image_selected.class != Array || image_selected.length > 0)

        # Use the Engine instance to remove the selected image from the database
        engine = ProjectRazor::Engine.instance
        return_status = false
        begin
          return_status = engine.remove_image(image_selected)
        rescue RuntimeError => e
          raise ProjectRazor::Error::Slice::InternalError, e.message
        rescue Exception => e
          # if got to here, then the Engine raised an exception
          raise ProjectRazor::Error::Slice::CouldNotRemove, e.message
        end
        if return_status
          slice_success("")
          puts "\nImage: " + "#{image_selected.uuid}".yellow + " removed successfully"
        else
          raise ProjectRazor::Error::Slice::InternalError, "cannot remove image '#{image_selected.uuid}' from db"
        end
      end

    end
  end
end
