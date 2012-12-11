module ProjectRazor
  module ModelTemplate

    class OracleLinux6 < Redhat
      include(ProjectRazor::Logging)

      def initialize(hash)
        super(hash)
        # Static config
        @hidden      = false
        @name        = "oraclelinux_6"
        @description = "Oracle Linux 6 Model"
        @osversion   = "6"

        from_hash(hash) unless hash == nil
      end
    end
  end
end
