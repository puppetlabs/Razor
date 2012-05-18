# Root ProjectRazor namespace
module ProjectRazor
  module ModelTemplate
    # Root Model object
    # @abstract
    class VMwareESXi5 < ProjectRazor::ModelTemplate::VMwareESXi

      def initialize(hash)
        super(hash)
        # Static config
        @hidden = false
        @name = "vmware_esxi_5"
        @description = "VMware ESXi 5 Deployment"
        @osversion = "5"
        from_hash(hash) unless hash == nil
      end
    end
  end
end
