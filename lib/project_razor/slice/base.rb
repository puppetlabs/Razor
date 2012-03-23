# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved

require "json"
require "colored"

# TODO - change help printing to multi-line with header and description

# Root ProjectRazor namespace
# @author Nicholas Weaver
module ProjectRazor
  module Slice
    # Abstract parent class for all ProjectRazor Modules
    # @abstract
    # @author Nicholas Weaver
    class Base
      include(ProjectRazor::Logging)
      include(ProjectRazor::SliceUtil::Common)

      # Bool for indicating whether this was driven from Node.js
      attr_accessor :web_command
      attr_accessor :verbose
      attr_accessor :debug

      # Initializes the Slice Base
      # @param [Array] args
      def initialize(args)
        @command_array = args
        @slice_commands = {}
        @web_command = false
      end

      # Default call method for a slice
      # Used by {./bin/project_razor}
      # Parses the #command_array and determines the action based on #slice_commands for child object
      def slice_call
        # First var in array should be our root command
        @command = @command_array.shift
        # check command and route based on it
        flag = false
        @command = "default" if @command == nil

        @slice_commands.each_pair do
        |cmd_string, method|
          if @command == cmd_string.to_s
            logger.debug "Slice command called: #{@command}"
            self.send(method)
            flag = true
          end
        end

        if @command == "help"
          available_commands(nil)
        else
          slice_error("InvalidCommand", false) unless flag
        end
      end

      # Called when slice action is successful
      # Returns a json string representing a [Hash] with metadata and response
      # @param [Hash] response
      def slice_success(response, mk_response = false)
        return_hash = {}
        return_hash["resource"] = self.class.to_s
        return_hash["command"] = @command
        return_hash["result"] = "success"
        return_hash["errcode"] = 0
        return_hash["response"] = response
        setup_data
        return_hash["client_config"] = @data.config.get_client_config_hash if mk_response
        if @web_command
          puts JSON.dump(return_hash)
        else
          print "\n\n#{@slice_name.capitalize}"
          print " #{return_hash["command"]}"
          print " #{return_hash["result"]}"
        end
        logger.debug "(#{return_hash["resource"]}  #{return_hash["command"]}  #{return_hash["result"]})"
      end

      # Called when a slice action triggers an error
      # Returns a json string representing a [Hash] with metadata including error code and message
      # @param [Hash] error
      def slice_error(error, mk_response = false)
        @command = "null" if @command == nil

        return_hash = {}
        return_hash["slice"] = self.class.to_s
        return_hash["command"] = @command
        return_hash["errcode"] = 1
        return_hash["result"] = error
        setup_data
        return_hash["client_config"] = @data.config.get_client_config_hash if mk_response
        if @web_command
          puts JSON.dump(return_hash)
        else
          available_commands(return_hash)
        end
        logger.error "Slice error: #{return_hash.inspect}"
      end

      # Prints available commands to CLI for slice
      # @param [Hash] return_hash
      def available_commands(return_hash)
        print "\nAvailable commands for [#{@slice_name}]:\n"
        @slice_commands.each do
        |k,y|
          print "[#{k}] ".yellow unless k == :default
        end
        print "\n\n"
        if return_hash != nil
          print "[#{@slice_name.capitalize}] "
          print "[#{return_hash["command"]}] ".red
          print "<-#{return_hash["result"]}\n".yellow
          puts "\nCommand syntax:" + " #{@slice_commands_help[@command]}".red + "\n" unless @slice_commands_help[@command] == nil
        end
      end

      # Initializes [ProjectRazor::Data] in not already instantiated
      def setup_data
        @data = ProjectRazor::Data.new unless @data.class == ProjectRazor::Data
      end
    end
  end
end