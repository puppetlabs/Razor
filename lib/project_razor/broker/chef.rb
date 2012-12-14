# Our chef plugin which contains the agent & device proxy classes used for hand off

require "erb"
require "net/ssh"
require 'digest/md5'
require 'uri'

# Root namespace for ProjectRazor
module ProjectRazor::BrokerPlugin

  # Root namespace for Chef Broker plugin defined in ProjectRazor for node handoff
  class Chef < ProjectRazor::BrokerPlugin::Base
    include(ProjectRazor::Logging)

    def initialize(hash)
      super(hash)

      @plugin = :chef
      @description = "Opscode Chef"
      @hidden = false
      from_hash(hash) if hash
      @req_metadata_hash = {
        "@chef_server_url" => {
          :default      => "",
          :example      => "https://chef.example.com:4000",
          :validation   => URI::regexp.to_s,
          :required     => true,
          :description  => "the URL for the Chef server."
        },
        "@chef_version" => {
          :default      => "",
          :example      => "10.16.2",
          :validation   => '^[0-9]+\.[0-9]+\.[0-9]+(\.[a-zA-Z0-9\.]+)?$',
          :required     => true,
          :description  => "the Chef version (used in gem install)."
        },
        "@validation_key" => {
          :default      => "",
          :example      => "-----BEGIN RSA PRIVATE KEY-----\\nMIIEpAIBAA...",
          :validation   => '.*',
          :required     => true,
          :description  => "a paste of the contents of the validation.pem file, followed by a blank line.",
          :multiline    => true
        },
        "@validation_client_name" => {
          :default      => "chef-validator",
          :example      => "myorg-validator",
          :validation   => '^[\w._-]+$',
          :required     => true,
          :description  => "the validation client name."
        },
        "@bootstrap_environment" => {
          :default      => "_default",
          :example      => "production",
          :validation   => '^[\w._-]+$',
          :required     => true,
          :description  => "the Chef environment in which the chef-client will run."
        },
        "@install_sh_url" => {
          :default      => "http://opscode.com/chef/install.sh",
          :example      => "http://mirror.example.com/install.sh",
          :validation   => URI::regexp.to_s,
          :required     => true,
          :description  => "the Omnibus installer script URL."
        },
        "@chef_client_path" => {
          :default      => "chef-client",
          :example      => "/usr/local/bin/chef-client",
          :validation   => '^[\w._-]+$',
          :required     => true,
          :description  => "an alternate path to the chef-client binary."
        },
        "@base_run_list" => {
          :default      => "",
          :example      => "role[base],role[another]",
          :validation   => '^(role|recipe)\[[^\]]+\](\s*,\s*(role|recipe)\[[^\]]+\])*$',
          :required     => false,
          :description  => "an optional run_list of common base roles."
        },
      }
    end

    def print_item_header
      if @is_template
        return "Plugin", "Description"
      else
        return "Name", "Description", "Plugin", "UUID", "Chef Server URL", "Chef Version", "Validation Key MD5 Hash", 
                "Validation Client Name", "Bootstrap Environment", "Install Sh Url", "Chef Client Path", "Base Run List"
      end
    end

    def print_item
      if @is_template
        return @plugin.to_s, @description.to_s
      else
        return @name, @user_description, @plugin.to_s, @uuid, @chef_server_url, @chef_version, Digest::MD5.hexdigest(@validation_key),
               @validation_client_name, @bootstrap_environment, @install_sh_url, @chef_client_path, @base_run_list
      end
    end

    def agent_hand_off(options = {})
      @options = options
      return false unless validate_options(@options, [:username, :password, :ipaddress])
      @chef_script = compile_template
      init_agent(options)
    end

    def init_agent(options={})
      @run_script_str = ""
      begin
        Net::SSH.start(options[:ipaddress], options[:username], { :password => options[:password], :user_known_hosts_file => '/dev/null'} ) do |session|
          @run_script_str << session.exec!("bash -c '#{@chef_script}' 2>&1 | tee /tmp/chef_bootstrap.log")
        end
      rescue => e
        logger.error "Chef bootstrap error: #{e}"
        return :broker_fail
      end

      logger.debug "Chef bootstrap output:\n---\n#{@run_script_str}\n---"

      # set return to fail by default
      ret = :broker_fail
      # set to success (this meant autosign was likely on)
      ret = :broker_success if @run_script_str =~ /^#{BROKER_SUCCESS_MSG}$/
      ret
    end


    def compile_template
      logger.debug "Compiling template"
      install_script = File.join(File.dirname(__FILE__), "chef/chef_bootstrap.erb")
      contents = ERB.new(File.read(install_script)).result(binding)
      logger.debug "Chef bootstrap script:\n---\n#{contents}\n---"
      contents
    end

    def validate_options(options, req_list)
      missing_opts = req_list.select do |opt|
        options[opt] == nil
      end
      unless missing_opts.empty?
        false
      end
      true
    end

    private

    BROKER_SUCCESS_MSG = "Razor Chef bootstrap completed."

    attr_reader :install_sh_url, :chef_version, :validation_key, :base_run_list

    def config_content
      <<-CONFIG.gsub(/^ +/, '')
        log_level               :info
        log_location            STDOUT
        chef_server_url         "#{@chef_server_url}"
        validation_client_name  "#{@validation_client_name}"
      CONFIG
    end

    # Constructs a Chef run_list as a concatenation of a base_run_list and
    # any roles/recipes found in razor tags
    #
    # Razor tags that are Chef run_list entries will be of the form
    # "role__web_server" or "recipe__mysql__server", and will be translated
    # to "role[web_server]" and "recipe[mysql::server]" respectively.
    def run_list
      run_list = Array(base_run_list && base_run_list.split(/\s*,\s*/))
      if @options[:metadata][:razor_tags]
        tag_string = @options[:metadata][:razor_tags]
        run_list_tags = tag_string.split(',').select do |tag|
          tag =~ /^(role|recipe)__/
        end
        tagged_run_list = run_list_tags.map do |tag|
          tag.sub(/^(role|recipe)__(.+)$/, '\1[\2]').gsub(/__/, '::')
        end
        run_list += Array(tagged_run_list)
      end
      run_list
    end

    def razor_detail_data
      node = get_data.fetch_object_by_uuid(:node, @options[:uuid])
      razor_details = node.attributes_hash
      logger.debug "---------------razor details: #{razor_details}"  
      razor_details
    end

    def first_boot
      {
        :razor_metadata => @options[:metadata],
        :razor_attributes => razor_detail_data,
        :run_list => run_list
      }
    end

    def start_chef
      [ %{#{@chef_client_path} -j /etc/chef/first-boot.json -E #{@bootstrap_environment}},
        %{echo "#{BROKER_SUCCESS_MSG}"}
      ].join("\n")
    end
  end
end
