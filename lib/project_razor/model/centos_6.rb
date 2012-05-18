module ProjectRazor
  module ModelTemplate

    class Centos6 < Redhat
      include(ProjectRazor::Logging)

      # Assigned image
      attr_accessor :image_uuid
      # Metadata
      attr_accessor :hostname
      # Compatible Image Prefix
      attr_accessor :image_prefix

      def initialize(hash)
        super(hash)
        # Static config
        @hidden = false
        @template = :linux_deploy
        @name = "centos_6"
        @description = "CentOS 6 Model"
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
        @osversion = "6"
        @final_state = :os_complete
        from_hash(hash) unless hash == nil
        @req_metadata_hash = {
            "@hostname_prefix" => {
                :default     => "node",
                :example     => "node",
                :validation  => '^[\w]+$',
                :required    => true,
                :description => "node hostname prefix (will append node number)"
            },
            "@root_password" => {
                :default     => "test1234",
                :example     => "P@ssword!",
                :validation  => '^[\S]{8,}',
                :required    => true,
                :description => "root password (> 8 characters)"
            },
        }
      end
    end
  end
end
