require "erb"

# Root ProjectRazor namespace
module ProjectRazor
  module ModelTemplate
    # Root Model object
    # @abstract
    class DTAGCloudUbuntuCompute < Ubuntu
      include(ProjectRazor::Logging)

      def initialize(hash)
        super(hash)
        # Static config
        @hidden = false
        @name = "dtagcloud_ubuntu_compute"
        @description = "DTAG Cloud Compute"
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
        filepath = template_filepath('dtagcloud_ubuntu_compute')
        ERB.new(File.read(filepath)).result(binding)
      end

      def kernel_args(policy_uuid)
        filepath = template_filepath('dtagcloud_kernel_args_compute')
        ERB.new(File.read(filepath)).result(binding)
      end

    end
  end
end
