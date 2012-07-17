# Root ProjectRazor namespace
module ProjectRazor
  module ModelTemplate
    # Root Model object
    # @abstract
    class DebianWheezy < Debian
      include(ProjectRazor::Logging)

      def initialize(hash)
        super(hash)
        # Static config
        @hidden = false
        @name = "debian_wheezy"
        @description = "Debian Wheezy Model"
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
        @osversion = 'wheezy'
        @final_state = :os_complete
        from_hash(hash) unless hash == nil
      end

    end
  end
end
