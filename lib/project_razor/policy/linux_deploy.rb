# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved

# ProjectRazor Policy Base class
# Root abstract
module ProjectRazor
  module Policy
    class LinuxDeploy < ProjectRazor::Policy::Base
      attr_accessor :kernel_path


      # @param hash [Hash]
      def initialize(hash)
        super(hash)
        @hidden = false
        @policy_type = :linux_deploy
        @description = "Policy for deploying a Linux-based operating system. Compatible with Linux operating system Model Configs"

        from_hash(hash) unless hash == nil
      end


      def mk_call(node)
        # Placeholder - tell it to reboot
        logger.debug "Telling our node to reboot (placeholder)"
        [:reboot, {}]
      end

      # Called from a node bound to this policy does a boot and requires a script
      def boot_call(node)





      end


      def kernel_line
        @model.kernel_line
      end

      def module_line
        @model.module_line
      end

    end
  end
end