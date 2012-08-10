require "erb"

# Root ProjectRazor namespace
module ProjectRazor
  module ModelTemplate
    # Root Model object
    # @abstract
    class UbuntuPreciseIPPool < Ubuntu
      include(ProjectRazor::Logging)

      def initialize(hash)
        super(hash)
        # Static config
        @hidden          = false
        @name            = "ubuntu_precise_ip_pool"
        @description     = "Ubuntu Precise Model (IP Pool)"
        # Metadata vars
        @hostname_prefix = nil
        # State / must have a starting state
        @current_state   = :init
        # Image UUID
        @image_uuid      = true
        # Image prefix we can attach
        @image_prefix    = "os"
        # Enable agent brokers for this model
        @broker_plugin   = :agent
        @osversion       = 'precise_ip_pool'
        @final_state     = :os_complete
        @ip_range_network        = nil
        @ip_range_subnet         = nil
        @ip_range_start          = nil
        @ip_range_end            = nil
        @gateway                 = nil
        @hostname_prefix         = nil
        @req_metadata_hash = {
            "@hostname_prefix" => {
                :default     => "node",
                :example     => "node",
                :validation  => '^[a-zA-Z0-9][a-zA-Z0-9\-]*$',
                :required    => true,
                :description => "node hostname prefix (will append node number)"
            },
            "@domainname"      => {
                :default     => "localdomain",
                :example     => "example.com",
                :validation  => '^[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9](\.[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9])*$',
                :required    => true,
                :description => "local domain name (will be used in /etc/hosts file)"
            },
            "@root_password"   => {
                :default     => "test1234",
                :example     => "P@ssword!",
                :validation  => '^[\S]{8,}',
                :required    => true,
                :description => "root password (> 8 characters)"
            },
            "@ip_range_network"        => { :default     => "",
                                            :example     => "192.168.10",
                                            :validation  => '^\b(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b$',
                                            :required    => true,
                                            :description => "IP Network for hosts" },
            "@ip_range_subnet"         => { :default     => "255.255.255.0",
                                            :example     => "255.255.255.0",
                                            :validation  => '^\b(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b$',
                                            :required    => true,
                                            :description => "IP Subnet" },
            "@ip_range_start"          => { :default     => "",
                                            :example     => "1",
                                            :validation  => '^\b(25[0-4]|2[0-4][0-9]|[01]?[0-9][0-9]?)$',
                                            :required    => true,
                                            :description => "Starting IP address (1-254)" },
            "@ip_range_end"            => { :default     => "",
                                            :example     => "50",
                                            :validation  => '^\b(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$',
                                            :required    => true,
                                            :description => "Ending IP address (2-255)" },
            "@gateway"                 => { :default     => "",
                                            :example     => "192.168.1.1",
                                            :validation  => '^\b(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b$',
                                            :required    => true,
                                            :description => "Gateway for node" },
        }

        from_hash(hash) unless hash == nil
      end

      def node_ip_address
        "#{@ip_range_network}.#{(@ip_range_start..@ip_range_end).to_a[@counter - 1]}"
      end

    end
  end
end
