require "erb"

# Root ProjectRazor namespace
module ProjectRazor
  module ModelTemplate
    # Root Model object
    # @abstract
    class UbuntuPrecise < Ubuntu
      include(ProjectRazor::Logging)

      def initialize(hash)
        super(hash)
        # Static config
        @hidden          = false
        @name            = "ubuntu_precise_ip_pool"
        @description     = "Ubuntu Precise Model (IP Pool)
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
        @osversion       = 'precise'
        @final_state     = :os_complete

        req_metadata_hash = {
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
            "@nameserver"              => { :default     => "",
                                            :example     => "192.168.10.10",
                                            :validation  => '^\b(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b$',
                                            :required    => true,
                                            :description => "Nameserver for node" },
            "@ntpserver"               => { :default     => "",
                                            :example     => "ntp.razor.example.local",
                                            :validation  => '^[\w.]{3,}$',
                                            :required    => true,
                                            :description => "NTP server for node" },
        }

        from_hash(hash) unless hash == nil
      end

    end
  end
end
