require "json"
require "yaml"

# Root ProjectRazor namespace
module ProjectRazor
  module Slice

    # TODO - add inspection to prevent duplicate MK's with identical version to be added

    # ProjectRazor Slice Image
    # Used for image management
    class Image < ProjectRazor::Slice::Base

      # Initializes ProjectRazor::Slice::Model including #slice_commands, #slice_commands_help, & #slice_name
      # @param [Array] args
      def initialize(args)
        super(args)
        @hidden = false
        @new_slice_style = true # switch to new slice style
                                # Here we create a hash of the command string to the method it corresponds to for routing.
        @slice_commands = {
            :add     => {
                :default => "add_image",
                :help    => "razor image add " + "[#{get_types}]".white + " [/path/to/image] (os_name) (os_version)".yellow,
                :else    => :default,
            },
            :get     => "list_images",
            :remove  => {
                :default => "remove_image",
                :help    => "razor image remove " + "(IMAGE UUID)".yellow,
                :else    => :default,
            },
            :default => "list_images",
            :path    => "get_path",
            :else    => :help,
            :help    => 'razor image [add|get|remove|path]',
        }
        @slice_name = "Image"
      end

      #Gets the path to an image or image element
      # /mk/kernel - gets default mk kernel
      # /mk/initrd - gets default mk initrd
      # /%uuid&/%path to file% - gets the file from relative path for image with %uuid%

      def get_types
        @image_types = get_child_types("ProjectRazor::ImageService::")
        @image_types.map {|x| x.path_prefix.yellow unless x.hidden}.compact.join("|".red)
      end

      def get_path
        if @web_command
          @arg = @command_array.shift
          if @arg != nil
            case @arg

              when "mk"
                get_mk_paths
              else
                get_path_with_uuid(@arg)
            end
          else
            raise ProjectRazor::Error::Slice::MissingArgument, 'image type'
          end
        else
          raise ProjectRazor::Error::Slice::NotImplemented, 'REST only'
        end
      end

      def get_mk_paths
        engine = ProjectRazor::Engine.instance
        default_mk_image = engine.default_mk
        raise ProjectRazor::Error::Slice::MissingMK unless default_mk_image != nil

        @option = @command_array.shift
        raise ProjectRazor::Error::Slice::MissingOption unless @option

        setup_data
        case @option
          when "kernel"
            slice_success(default_mk_image.kernel_path)
          when "initrd"
            slice_success(default_mk_image.initrd_path)
          else
            raise ProjectRazor::Error::Slice::InvalidArgument, @option
        end
      end

      def get_path_with_uuid(uuid)
        @image_uuid = uuid

        raise ProjectRazor::Error::Slice::MissingArgument, '[uuid]' unless validate_arg(@image_uuid)

        @image_uuid = "95a1f9b05672012f5a86000c29a78d16" if @image_uuid == "nick"

        setup_data
        @image = @data.fetch_object_by_uuid(:images, @image_uuid)

        raise ProjectRazor::Error::Slice::InvalidImageUUID, uuid unless @image != nil

        @image.set_image_svc_path(@data.config.image_svc_path)

        @command_array.each do |a|
          raise ProjectRazor::Error::Slice::InvalidPathItem, a unless /^[^ \/\\]+$/ =~ a
        end
        file_path = @image.image_path + "/" + @command_array.join("/")


        if File.directory?(file_path)
          slice_success(file_path)
        else
          raise ProjectRazor::Error::Slice::InvalidImageFilePath, file_path
        end
      end

      #Lists images
      def list_images
        raise ProjectRazor::Error::Slice::NotImplemented, "image list cli only" if @web_command
        print_images get_object("images", :images)
      end

      #Add an image
      def add_image
        @command = :add
        setup_data
        image_types = {:mk => {:desc => "MicroKernel ISO",
                               :classname => "ProjectRazor::ImageService::MicroKernel",
                               :method => "add_mk"},
                       :os => {:desc => "OS Install ISO",
                               :classname => "ProjectRazor::ImageService::OSInstall",
                               :method => "add_os"},
                       :esxi => {:desc => "VMware Hypervisor ISO",
                                 :classname => "ProjectRazor::ImageService::VMwareHypervisor",
                                 :method => "add_esxi"}}

        raise ProjectRazor::Error::Slice::NotImplemented, "image add cli only" if @web_command

        image_type = @command_array.shift

        unless ([image_type.to_sym] - image_types.keys).size == 0
          print_types(image_types)
          raise ProjectRazor::Error::Slice::InvalidImageType, image_type
        end

        iso_path = @command_array.shift
        raise ProjectRazor::Error::Slice::MissingArgument, '[/path/to/iso]' unless iso_path != nil && iso_path != ""

        classname = image_types[image_type.to_sym][:classname]

        new_image = ::Object::full_const_get(classname).new({})
        # We send the new image object to the appropriate method
        res = self.send image_types[image_type.to_sym][:method], new_image, iso_path, @data.config.image_svc_path

        raise ProjectRazor::Error::Slice::InternalError, res[1] unless res[0]

        raise ProjectRazor::Error::Slice::InternalError, "Could not save image." unless insert_image(new_image)

        puts "\nNew image added successfully\n".green
        print_images [new_image]
      end

      def add_mk(new_image, iso_path, image_svc_path)
        puts "Attempting to add, please wait...".green
        new_image.add(iso_path, image_svc_path, nil)
      end

      def add_esxi(new_image, iso_path, image_svc_path)
        puts "Attempting to add, please wait...".green
        new_image.add(iso_path, image_svc_path, nil)
      end

      def add_os(new_image, iso_path, image_svc_path)
        os_name = @command_array.shift
        raise ProjectRazor::Error::Slice::MissingArgument, '[os_name]' if os_name == nil

        os_version = @command_array.shift
        raise ProjectRazor::Error::Slice::MissingArgument, '[os_version]' if os_version == nil

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
        @command = :remove

        raise ProjectRazor::Error::Slice::NotImplemented, 'CLI only' if @web_command
        image_uuid = @command_array.shift
        raise ProjectRazor::Error::Slice::MissingArgument, '[uuid]' unless image_uuid

        setup_data
        image_selected = @data.fetch_object_by_uuid(:images, image_uuid)
        raise ProjectRazor::Error::Slice::InvalidUUID unless image_selected

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
          puts "\nImage: " + "#{image_uuid}".yellow + " removed successfully"
        else
          raise ProjectRazor::Error::Slice::InternalError, "cannot remove image '#{image_uuid}' from db"
        end
      end

    end
  end
end
