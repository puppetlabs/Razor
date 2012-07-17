module ProjectRazor
  module ModelTemplate

    class Redhat6 < Redhat
      include(ProjectRazor::Logging)

      def initialize(hash)
        super(hash)
        # Static config
        @hidden      = false
        @name        = "redhat_6"
        @description = "RedHat 6 Model"
        @osversion   = "6"

        from_hash(hash) unless hash == nil
      end
    end
  end
end
