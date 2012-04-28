# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved

# ProjectRazor Policy Base class
# Root abstract
module ProjectRazor
  module Policy
    class VMwareHypervisor < ProjectRazor::Policy::Base
      include(ProjectRazor::Logging)

      # @param hash [Hash]
      def initialize(hash)
        super(hash)
        @hidden = false
        @type = :vmware_hypervisor
        @description = "Policy for deploying a VMware hypervisor. Compatible with VMware hypervisor Model Configs"

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