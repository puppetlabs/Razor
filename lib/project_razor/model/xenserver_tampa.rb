# Root ProjectRazor namespace
module ProjectRazor
  module ModelTemplate
    # Root Model object
    # @abstract
    class XenServerTampa < ProjectRazor::ModelTemplate::XenServer

      def initialize(hash)
        super(hash)
        # Static config
        @hidden = false
        @name = "xenserver_tampa"
        @description = "Citrix XenServer 6.1 (tampa) Deployment"
        @osversion = "tampa"
        from_hash(hash) unless hash == nil
      end
    end
  end
end

