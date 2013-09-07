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
        @name = "dtagcloud_ubuntu_vm_bootstrap"
        @description = "DTAG Cloud VM Bootstrap"
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

      def os_boot_script(policy_uuid)
        @result = "Replied with os boot script"
        filepath = template_filepath('os_boot_vm_bootstrap')
        ERB.new(File.read(filepath)).result(binding)
      end

      def postinstall_call
        @arg = @args_array.shift
        case @arg
          when "inject"
            fsm_action(:postinstall_inject, :postinstall)
            return os_boot_script(@policy_uuid)
          when "boot"
            fsm_action(:os_boot, :postinstall)
            return os_complete_script(@node)
          when "final"
            fsm_action(:os_final, :postinstall)
            return ""
          when "source_fix"
            fsm_action(:source_fix, :postinstall)
            return
          when "send_ips"
            #fsm_action(:source_fix, :postinstall)
            # Grab IP string
            @ip_string = @args_array.shift
            logger.debug "Node IP String: #{@ip_string}"
            @node_ip = @ip_string if @ip_string =~ /\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b/
            return
          else
            fsm_action(@arg.to_sym, :postinstall)
            return
        end
      end



      def generate_preseed(policy_uuid)
        filepath = template_filepath('dtagcloud_ubuntu_vm_bootstrap')
        ERB.new(File.read(filepath)).result(binding)
      end

      def kernel_args(policy_uuid)
        filepath = template_filepath('dtagcloud_kernel_args_vm')
        ERB.new(File.read(filepath)).result(binding)
      end



    end
  end
end
