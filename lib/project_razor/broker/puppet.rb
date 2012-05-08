# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved

# Our puppet plugin which contains the agent & device proxy classes used for hand off

# TODO - Make broker properties open rather than rigid
require "erb"
require "net/ssh"

# Root namespace for ProjectRazor
# @author Nicholas Weaver
module ProjectRazor::BrokerPlugin

  # Root namespace for Puppet Broker plugin defined in ProjectRazor for node handoff
  # @author Nicholas Weaver
  class Puppet < ProjectRazor::BrokerPlugin::Base
    include(ProjectRazor::Logging)

    def initialize(hash)
      super(hash)

      @plugin = :puppet
      @description = "PuppetLabs PuppetMaster"
      @hidden = false
      from_hash(hash) if hash
    end

    def agent_hand_off(options = {})
      @options = options
      @options[:server] = @servers.first
      @options[:ca_server] = @options[:server]
      @options[:puppetagent_certname] ||= @options[:hostname]
      return false unless validate_options(@options, [:username, :password, :server, :ca_server, :puppetagent_certname, :ipaddress])
      @puppet_script = compile_template
      init_agent(options)
    end

    def proxy_hand_off(options = {})
      # Return false until we implement
      false
    end

    # Method call for validating that a Broker instance successfully received the node
    def validate_hand_off(options = {})
      # Return true until we add validation
      true
    end

    def init_agent(options={})
      @run_script_str = ""
      begin
        Net::SSH.start(options[:ipaddress], options[:username], :password => options[:password]) do |session|
          logger.debug "Copy: #{session.exec! "echo \"#{@puppet_script}\" > /tmp/puppet_init.sh" }"
          logger.debug "Chmod: #{session.exec! "chmod +x /tmp/puppet_init.sh"}"
          @run_script_str << session.exec!("bash /tmp/puppet_init.sh")
          @run_script_str.split("\n").each do |line|
            logger.debug "puppet script: #{line}"
          end
        end
      rescue => e
        logger.error "puppet agent error: #{p e}"
        return :broker_fail
      end
      # set return to fail by default
      ret = :broker_fail
      # set to wait
      ret = :broker_wait if @run_script_str.include?("Exiting; no certificate found and waitforcert is disabled")
      # set to success (this meant autosign was likely on)
      ret = :broker_success if @run_script_str.include?("Finished catalog run")
      ret
    end



    def compile_template
      logger.debug "Compiling template"
      install_script = File.join(File.dirname(__FILE__), "puppet/agent_install.erb")
      contents = ERB.new(File.read(install_script)).result(binding)
      logger.debug("Compiled installation script:")
      logger.error install_script
      #contents.split("\n").each {|x| logger.error x}
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
  end
end