# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved

# ProjectRazor Policy Base class
# Root abstract
module ProjectRazor
  module Policy
    class LinuxDeploy < ProjectRazor::Policy::Base

      # @param hash [Hash]
      def initialize(hash)
        super(hash)
        @hidden = false
        @policy_type = :linux_deploy
        @description = "Policy for deploying a Linux-based operating system. Compatible with Linux operating system Model Configs"

        from_hash(hash) unless hash == nil
      end


      def mk_call(node)
        model.mk_call(node, @uuid)
      end


      def boot_call(node)
        model.boot_call(node, @uuid)
      end

    end
  end
end