# Root ProjectRazor namespace
module ProjectRazor
  module ModelTemplate
    # Root Model object
    # @abstract
    class DebianSqueeze < Debian
      include(ProjectRazor::Logging)

      # Assigned image
      attr_accessor :image_uuid
      # Compatible Image Prefix
      attr_accessor :image_prefix

      def initialize(hash)
        super(hash)
        # Static config
        @hidden = false
        @name = "debian_squeeze"
        @description = "Debian Squeeze Model"
        # Metadata vars
        @hostname_prefix = nil
        # State / must have a starting state
        @current_state = :init
        # Image UUID
        @image_uuid = true
        # Image prefix we can attach
        @image_prefix = "os"
        # Enable agent brokers for this model
        # @broker_plugin = :agent
        @osversion = 'squeeze'
        @final_state = :os_complete
        from_hash(hash) unless hash == nil
      end

    end
  end
end
