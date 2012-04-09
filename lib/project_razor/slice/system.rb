# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved

require "json"

# Root ProjectRazor namespace
# @author Nicholas Weaver
module ProjectRazor
  module Slice

    # ProjectRazor Slice System
    # Used for system management
    # @author Nicholas Weaver
    class System < ProjectRazor::Slice::Base
      # Initializes ProjectRazor::Slice::Model including #slice_commands, #slice_commands_help, & #slice_name
      # @param [Array] args
      def initialize(args)
        super(args)
        # Here we create a hash of the command string to the method it corresponds to for routing.
        @slice_commands = {:add => "add_system",
                           :get => "get_system",
                           :default => "get_system",
                           :remove => "remove_system",
                           :else => "get_system"} # Catches invalid commands
        @slice_commands_help = {:get => "system ".red + "[all|types|(System UUID)]".yellow,
                                :add => "system " + "(system type) (Name) (Description) [options..]".yellow,
                                :remove => "system " + "(System UUID)".yellow}
        @slice_name = "System"
      end

      # Returns all systems, all systems types (with [types]), or a system object (with [uuid])
      def get_system
        # Set our @command for enabling help return
        @command = :get
        # Get the next argument in our command array
        @arg = @command_array.shift

        #Examine our arg and figure out what is being requested
        case @arg
          when nil, "all" # nil or [all] will return all system instances
            get_system_all
          when "types"  # [types] wil list all system types
            get_system_types
          else # else will validate the uuid and attempt to return a system with this uuid
            get_system_with_uuid
        end
      end

      # Returns all system instances
      def get_system_all
        # Get al system instances and print/return
        print_object_array get_object("system_instances", :system) , "System Instances:"
      end

      def get_system_types

      end

      def get_system_with_uuid

      end


    end
  end
end

