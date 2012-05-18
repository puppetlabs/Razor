# Root namespace for ProjectRazor
module ProjectRazor::BrokerPlugin

  class VCenter < ProjectRazor::BrokerPlugin::Base
    include(ProjectRazor::Logging)

    def initialize(hash)
      super(hash)

      @plugin = :vcenter
      @description = "Register ESXi node in vCenter"
      @hidden = false
      from_hash(hash) if hash
    end

    def agent_hand_off(options = {})
    end

    def proxy_hand_off(options = {})
      res = "
      @@vc_host { '#{options[:hostname]}':
        ensure   => 'present',
        username => '#{options[:username]}',
        password => '#{options[:password]}',
        tag      => '#{options[:vcenter_name]}',
      }
      "
      system("puppet apply --certname=#{options[:hostname]} --report -e \"#{res}\"")
      :broker_success
    end

    # Method call for validating that a Broker instance successfully received the node
    def validate_hand_off(options = {})
      # Return true until we add validation
      true
    end
  end
end
