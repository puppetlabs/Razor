module ProjectRazor
  module ImageService
    # Image construct for generic Operating System install ISOs
    class OSInstall < ProjectRazor::ImageService::Base

      attr_accessor :os_name
      attr_accessor :os_version

      def initialize(hash)
        super(hash)
        @description = "OS Install"
        @path_prefix = "os"
        @hidden = false
        from_hash(hash) unless hash == nil
      end

      def add(src_image_path, image_svc_path, extra)
        begin
          resp = super(src_image_path, image_svc_path, extra)
          if resp[0]
            @os_name = extra[:os_name]
            @os_version = extra[:os_version]
          else
            resp
          end
        rescue => e
          logger.error e.message
          return [false, e.message]
        end
      end

      def verify(image_svc_path)
        super(image_svc_path)
      end

      def print_item_header
        super.push "OS Name", "OS Version"
      end

      def print_item
        super.push @os_name.to_s, @os_version.to_s
      end

    end
  end
end
