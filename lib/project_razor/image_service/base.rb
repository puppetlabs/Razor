require "fileutils"
require "digest/sha2"

module ProjectRazor
  module ImageService
    # Base image abstract
    class Base < ProjectRazor::Object

      MOUNT_COMMAND = (Process::uid == 0 ? "mount" : "sudo mount")
      UMOUNT_COMMAND = (Process::uid == 0 ? "umount" : "sudo umount")

      attr_accessor :filename
      attr_accessor :description
      attr_accessor :size
      attr_accessor :verification_hash
      attr_accessor :path_prefix
      attr_accessor :hidden

      def initialize(hash)
        super()
        @path_prefix = "base"
        @_namespace = :images
        @noun = "image"
        @description = "Image Base"
        @hidden = true
        from_hash(hash) unless hash == nil
      end

      def set_image_svc_path(image_svc_path)
        @_image_svc_path = image_svc_path + "/" + @path_prefix
      end

      # Used to add an image to the service
      # Within each child class the methods are overridden for that child template
      def add(src_image_path, image_svc_path, extra)
        set_image_svc_path(image_svc_path)

        begin
          # Get full path
          fullpath = File.expand_path(src_image_path)
          # Get filename
          @filename = File.basename(fullpath)

          logger.debug "fullpath: #{fullpath}"
          logger.debug "filename: #@filename"
          logger.debug "mount path: #{mount_path}"

          # Make sure file exists
          return cleanup([false,"File does not exist"]) unless File.exist?(fullpath)

          # Make sure it has an .iso extension
          return cleanup([false,"File is not an ISO"]) if @filename[-4..-1] != ".iso"

          File.size(src_image_path)

          # Confirm a mount doesn't already exist
          unless is_mounted?(fullpath)
            unless mount(fullpath)
              logger.error "Could not mount #{fullpath} on #{mount_path}"
              return cleanup([false,"Could not mount"])
            end
          end

          # Determine if there is an existing image path for iso
          if is_image_path?
            ## Remove if there is
            remove_dir_completely(image_path)
          end

          ## Create image path
          unless create_image_path
            logger.error "Cannot create image path: #{image_path}"
            return cleanup([false, "Cannot create image path: #{image_path}"])
          end

          # Attempt to copy from mount path to image path
          copy_to_image_path

          # Verify diff between mount / image paths
          # For speed/flexibility reasons we just verify all files exists and not their contents
          @verification_hash = get_dir_hash(image_path)
          mount_hash = get_dir_hash(mount_path)
          unless mount_hash == @verification_hash
            logger.error "Image copy failed verification: #{@verification_hash} <> #{mount_hash}"
            return cleanup([false, "Image copy failed verification: #{@verification_hash} <> #{mount_hash}"])
          end

        rescue => e
          logger.error e.message
          return cleanup([false,e.message])
        end

        cleanup([true ,""])
      end

      # Used to remove an image to the service
      # Within each child class the methods are overridden for that child template
      def remove(image_svc_path)
        set_image_svc_path(image_svc_path) unless @_image_svc_path != nil
        cleanup([false ,""])
        !File.directory?(image_path)
      end

      # Used to verify an image within the filesystem (local/remote/possible Glance)
      # Within each child class the methods are overridden for that child emplate
      def verify(image_svc_path)
        set_image_svc_path(image_svc_path) unless @_image_svc_path != nil
        get_dir_hash(image_path) == @verification_hash
      end

      def image_path
        @_image_svc_path + "/" + @uuid
      end

      def is_mounted?(src_image_path)
        mounts.each do
        |mount|
          return true if mount[0] == src_image_path && mount[1] == mount_path
        end
        false
      end

      def mount(src_image_path)
        FileUtils.mkpath(mount_path) unless File.directory?(mount_path)

        `#{MOUNT_COMMAND} -o loop #{src_image_path} #{mount_path} 2> /dev/null`
        if $? == 0
          logger.debug "mounted: #{src_image_path} on #{mount_path}"
          true
        else
          logger.debug "could not mount: #{src_image_path} on #{mount_path}"
          false
        end
      end

      def umount
        `#{UMOUNT_COMMAND} #{mount_path} 2> /dev/null`
        if $? == 0
          logger.debug "unmounted: #{mount_path}"
          true
        else
          logger.debug "could not unmount: #{mount_path}"
          false
        end
      end

      def mounts
        `#{MOUNT_COMMAND}`.split("\n").map! {|x| x.split("on")}.map! {|x| [x[0],x[1].split(" ")[0]]}
      end

      def cleanup(ret)
        umount
        remove_dir_completely(mount_path)
        remove_dir_completely(image_path) if !ret[0]
        logger.error "Error: #{ret[1]}" if !ret[0]
        ret
      end

      def mount_path
        "#{$temp_path}/#{@uuid}"
      end

      def is_image_path?
        File.directory?(image_path)
      end

      def create_image_path
        FileUtils.mkpath(image_path)
      end

      def remove_dir_completely(path)
        if File.directory?(path)
          FileUtils.rm_r(path, :force => true)
        else
          true
        end
      end

      def copy_to_image_path
        FileUtils.cp_r(mount_path + "/.", image_path)
      end

      def get_dir_hash(dir)
        logger.debug "Generating hash for path: #{dir}"

        files_string = Dir.glob("#{dir}/**/*").map {|x| x.sub("#{dir}/","")}.sort.join("\n")
        Digest::SHA2.hexdigest(files_string)
      end


      def print_header
        return "UUID", "Type", "ISO Filename", "Path", "Status"
      end

      def print_items
        set_image_svc_path(ProjectRazor.config.image_svc_path) unless @_image_svc_path
        return @uuid, @description, @filename, image_path.to_s, "#{verify(@_image_svc_path) ? "Valid".green : "Broken/Missing".red}"
      end

      def print_item_header
        return "UUID", "Type", "ISO Filename", "Path", "Status"
      end

      def print_item
        set_image_svc_path(ProjectRazor.config.image_svc_path) unless @_image_svc_path
        return @uuid, @description, @filename, image_path.to_s, "#{verify(@_image_svc_path) ? "Valid".green : "Broken/Missing".red}"
      end

      def line_color
        :white_on_black
      end

      def header_color
        :red_on_black
      end
    end
  end
end
