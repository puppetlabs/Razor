require "erb"

# Root ProjectRazor namespace
module ProjectRazor
  module ModelTemplate
    # Root Model object
    # @abstract
    class DTAGCloudUbuntuStorage < Ubuntu
      include(ProjectRazor::Logging)

      def initialize(hash)
        super(hash)
        # Static config
        @hidden = false
        @name = "dtagcloud_ubuntu_storage"
        @description = "DTAG Cloud Storage"
        # Metadata vars
        @hostname_prefix = nil
        # State / must have a starting state
        @current_state = :init
        # Image UUID
        @image_uuid = true
        # Image prefix we can attach
        @image_prefix = "os"
        # Enable agent brokers for this model
        @broker_plugin = :agent
        @osversion = 'precise'
        @final_state = :os_complete
        from_hash(hash) unless hash == nil
      end

      def generate_preseed(policy_uuid)
        filepath = template_filepath('dtagcloud_ubuntu_storage')
        ERB.new(File.read(filepath)).result(binding)
      end

      def os_boot_script(policy_uuid)
        @result = "Replied with os boot script"
        filepath = template_filepath('dtagcloud_os_boot')
        ERB.new(File.read(filepath)).result(binding)
      end

    end
  end
end
