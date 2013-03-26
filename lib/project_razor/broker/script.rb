# Script Broker

require "erb"
require "net/ssh"
require "net/scp"
require 'json'
require 'stringio'

# Root namespace for ProjectRazor
module ProjectRazor::BrokerPlugin
  # Script Error
  class Error < RuntimeError; end
  class ScriptError < Error
    attr :return_code
    def initialize(return_code)
      @return_code = return_code
    end
  end

  # Root namespace for Script Broker plugin defined in ProjectRazor for node handoff.
  class Script < ProjectRazor::BrokerPlugin::Base
    include(ProjectRazor::Logging)

    def initialize(hash)
      super(hash)

      @hidden = false
      @plugin = :script
      @description = "Script Execution"
      @hidden = false
      from_hash(hash) if hash
      @req_metadata_hash = {
        "@script" => {
          :default      => "",
          :example      => "web-server.sh",
          :required     => true,
          :description  => "Script to be run.",
          :validation   => '.*',
        },
        "@script_path" => {
          :default      => "/tmp/razor_script",
          :example      => "/tmp/razor_script",
          :required     => false,
          :description  => "Script data path.",
          :validation   => '.*',
        },
        "@data" => {
          :default      => "",
          :example      => "data.tbz",
          :required     => false,
          :description  => "Script data resources.",
          :validation   => '.*',
        },
        "@data_path" => {
          :default      => "/tmp/razor_script_data",
          :example      => "/tmp/razor_script_data",
          :required     => false,
          :description  => "Script data path.",
          :validation   => '.*',
        },
        "@metadata_path" => {
          :default      => "/tmp/razor_script_metadata",
          :example      => "/tmp/razor_script_metadata",
          :required     => false,
          :description  => "Script metadata path.",
          :validation   => '.*',
        },
        "@log_path" => {
          :default      => "/tmp/razor_script.log",
          :example      => "/tmp/razor_script.log",
          :required     => false,
          :description  => "Script log path.",
          :validation   => '.*',
        },
      }
    end

    def print_item_header
      if @is_template
        return "Plugin", "Description"
      else
        return "Name", "Description", "Plugin", "UUID", "Script", "Script Path", "Data", "Data Path", "Metadata Path", "Log Path"
      end
    end

    def print_item
      if @is_template
        return @plugin.to_s, @description.to_s
      else
        return @name, @user_description, @plugin.to_s, @uuid, @script, @script_path, @data, @data_path, @metadata_path, @log_path
      end
    end

    def agent_hand_off(options = {})
      logger.debug 'Begin hand off.'

      options[:script] = @script
      options[:script_path] = @script_path
      options[:data] = @data
      options[:data_path] = @data_path
      options[:metadata_path] = @metadata_path
      options[:log_path] = @log_path

      logger.debug "Options processed: #{options.to_json}"

      @output = ""
      @attempts = 0

      begin
        Net::SSH.start(options[:ipaddress], options[:username], {:password => options[:password], :user_known_hosts_file => '/dev/null'}) do |session|
          scp = Net::SCP.new(session)

          # Install Script
          logger.debug 'Installing Script...'
          scp.upload! "#{options[:script]}", "#{options[:script_path]}"

          if not options[:data].empty?
            # Install Data
            logger.debug 'Installing Data...'
            scp.upload! "#{options[:data]}", "#{options[:data_path]}"
          end

          # Install Metadata
          logger.debug 'Installing Metadata...'
          scp.upload! StringIO.new("#{JSON.pretty_generate(options)}"), "#{options[:metadata_path]}"

          # Execute Script
          logger.debug 'Executing Script...'
          session.open_channel do |channel|
            channel.request_pty do |ch, success|
              logger.error 'Failed to get PTY... this _might_ break your script.' unless success
            end

            channel.on_request('exit-status') do |ch, data|
              return_code = data.read_long
              if return_code != 0
                raise ScriptError.new(return_code), "Script exited non-zero: #{return_code}"
              end
            end

            channel.on_data do |ch, data|
              @output << data
            end

            channel.on_extended_data do |ch, type, data|
              @output << data
            end

            channel.exec("#{options[:script_path]} #{options[:metadata_path]} 2>&1 | tee #{options[:log_path]}")
          end
        end
      rescue Net::SSH::ConnectionTimeout, Timeout::Error, Errno::EHOSTUNREACH, Errno::ECONNREFUSED
        if @attempts < 3 then
          @attempts += 1
          logger.warn "Razor script broker connection timed out (attempt: #{@attempts} of 3): #{e}"
          sleep(30)
          retry
        else
          logger.error "Razor script broker connection timed out (no more attempts left): #{e}"
          return :broker_fail
        end
      rescue => e
        logger.error "Razor script broker error: #{e}"
        logger.error "Razor script broker output:\n---\n#{@output}\n---"
        return :broker_fail
      end

      logger.debug "Razor script broker output:\n---\n#{@output}\n---"

      return :broker_success
    end
  end
end
