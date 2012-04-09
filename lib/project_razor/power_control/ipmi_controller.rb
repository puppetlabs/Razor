# IpmiController Class; a simple wrapper around the ipmitool interface that provides
# a mechanism for gathering information from an underlying BMC using the BMC's IPMI
# interface
#
# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved
#
#@author Tom McSweeney

require 'singleton'
require 'timeout'

# time to wait for an external command (in milliseconds)
EXT_COMMAND_TIMEOUT = 2000 unless EXT_COMMAND_TIMEOUT

module ProjectRazor
  module PowerControl
    class IpmiController < ProjectRazor::Object

      include Singleton

      def initialize
        super
        test = %x[which ipmitool]
        @ipmitool_exists = (test.length > 0)
      end

      # First, define a set of 'query-style' actions that will invoke corresponding
      # commands from the ipmitool command set

      # A wrapper method for the ipmitool's 'power status' command that can be used to obtain
      # the 'current power status' for the node with a specified IP address.
      #
      # @param host_ip [String] the IP address of the BMC to query for 'power status' information
      # @param username [String] the IPMI username to use for the query
      # @param passwd [String] the IPMI password to use for the query
      # @return [Array<Boolean, String>] an array containing a Boolean indicating whether or not the
      #     'power status' command succeeded and a String indicating what the 'power status' of that
      #     node actually is (either 'on' or 'off', or 'unknown')
      def power_status(host_ip, username, passwd)
        command_failed, power_output = run_ipmi_command(host_ip, username, passwd, 'power', 'status')
        if command_failed
          return [false, "unknown"]
        end
        power_output = power_output.split("\n")
        power_status = /.*(on|off)$/.match(power_output[0])[1]
        [true, power_status]
      end

      # A wrapper method for the ipmitool's 'bmc info' command that can be used to obtain the
      # 'bmc info' information for the node with a specified IP address (as a Hash map).
      #
      # @param (see #power_status)
      # @return [Array<Boolean, Hash>] an array containing a Boolean indicating whether or not the
      #     'bmc info' command succeeded and a Hash map containing 'bmc info' for that node
      def bmc_info(host_ip, username, passwd)
        command_failed, bmc_output = run_ipmi_command(host_ip, username, passwd, 'bmc', 'info')
        if command_failed
          return [false, {}]
        end
        bmc_hash = ipmi_output_to_hash(bmc_output, ':')
        [true, bmc_hash]
      end

      # A wrapper method for the ipmitool's 'bmc getenables' command that can be used to obtain the
      # 'bmc getenables' information for the node with a specified IP address (as a Hash map).
      #
      # @param (see #power_status)
      # @return [Array<Boolean, Hash>] an array containing a Boolean indicating whether or not the
      #     'bmc getenables' command succeeded and a Hash map containing 'bmc getenables' for that node
      def bmc_getenables(host_ip, username, passwd)
        command_failed, bmc_output = run_ipmi_command(host_ip, username, passwd, 'bmc', 'getenables')
        if command_failed
          return [false, {}]
        end
        bmc_hash = ipmi_output_to_hash(bmc_output, ':')
        [true, bmc_hash]
      end

      # A wrapper method for the ipmitool's 'bmc guid' command that can be used to obtain the
      # 'bmc guid' information for the node with a specified IP address (as a Hash map).
      #
      # @param (see #power_status)
      # @return [Array<Boolean, Hash>] an array containing a Boolean indicating whether or not the
      #     'bmc guid' command succeeded and a Hash map containing 'bmc guid' for that node
      def bmc_guid(host_ip, username, passwd)
        command_failed, bmc_output = run_ipmi_command(host_ip, username, passwd, 'bmc', 'guid')
        if command_failed
          return [false, {}]
        end
        bmc_hash = ipmi_output_to_hash(bmc_output, ':')
        [true, bmc_hash]
      end

      # A wrapper method for the ipmitool's 'chassis status' command that can be used to obtain the
      # 'chassis status' information for the node with a specified IP address (as a Hash map).
      #
      # Returns the 'chassis status' (as a Hash map) for the node with the specified IP address.
      # @param (see #power_status)
      # @return [Array<Boolean, Hash>] an array containing a Boolean indicating whether or not the
      #     'chassis status' command succeeded and a Hash map containing 'chassis status' for that node
      def chassis_status(host_ip, username, passwd)
        command_failed, chassis_output = run_ipmi_command(host_ip, username, passwd, 'chassis', 'status')
        if command_failed
          return [false, {}]
        end
        chassis_hash = ipmi_output_to_hash(chassis_output, ':')
        [true, chassis_hash]
      end

      # A wrapper method for the ipmitool's 'lan print' command that can be used to obtain the
      # 'lan print' information for the node with a specified IP address (as a Hash map).
      #
      # @param (see #power_status)
      # @return [Array<Boolean, Hash>] an array containing a Boolean indicating whether or not the
      #     'lan print' command succeeded and a Hash map containing 'lan print' for that node
      def lan_print(host_ip, username, passwd)
        command_failed, lan_output = run_ipmi_command(host_ip, username, passwd, 'lan', 'print')
        if command_failed
          return [false, {}]
        end
        lan_hash = ipmi_output_to_hash(lan_output, ':')
        [true, lan_hash]
      end

      # A wrapper method for the ipmitool's 'fru print' command that can be used to obtain the
      # 'fru print' information for the node with a specified IP address (as a Hash map).
      #
      # @param (see #power_status)
      # @return [Array<Boolean, Hash>] an array containing a Boolean indicating whether or not the
      #     'fru print' command succeeded and a Hash map containing 'fru print' for that node
      def fru_print(host_ip, username, passwd)
        command_failed, fru_output = run_ipmi_command(host_ip, username, passwd, 'fru', 'print')
        if command_failed
          return [false, {}]
        end
        fru_hash = ipmi_output_to_hash(fru_output, ':')
        [true, fru_hash]
      end

      # Then, define a set of 'command-style' actions that will invoke corresponding
      # actions from the ipmitool command set (power on, power off, power cycle, )

      # A wrapper method for the ipmitool's 'power on' command that can be used to turn on a node
      # that is currently powered off.  Note that while it is not an error to try to power on a node that
      # is already turned on, the command to change the power state will have failed, so the success_flag
      # that is returned to the caller will be 'false' in that instance.
      #
      # @param (see #power_status)
      # @return [Array<Boolean, String>] an array containing a Boolean indicating whether or not the
      #     'power on' command succeeded and a String containing the results of that command
      def power_on(host_ip, username, passwd)
        command_failed, power_output = run_ipmi_command(host_ip, username, passwd, 'power', 'status')
        if command_failed
          return [false, power_output]
        end
        power_output = power_output.split("\n")
        power_status = /.*(on|off)$/.match(power_output[0])[1]
        if power_status == 'off'
          command_failed, power_output = run_ipmi_command(host_ip, username, passwd, 'power', 'on')
          power_output = power_output.split("\n")
          return [true, /.*(Up\/On)$/.match(power_output[0])[1]]
        end
        [false, 'Up/On']
      end

      # A wrapper method for the ipmitool's 'power off' command that can be used to turn off a node
      # that is currently powered on. Note that while it is not an error to try to power off a node that
      # is already turned off, the command to change the power state will have failed, so the success_flag
      # that is returned to the caller will be 'false' in that instance.
      #
      # @param (see #power_status)
      # @return [Array<Boolean, String>] an array containing a Boolean indicating whether or not the
      #     'power off' command succeeded and a String containing the results of that command
      def power_off(host_ip, username, passwd)
        command_failed, power_output = run_ipmi_command(host_ip, username, passwd, 'power', 'status')
        if command_failed
          return [false, power_output]
        end
        power_output = power_output.split("\n")
        power_status = /.*(on|off)$/.match(power_output[0])[1]
        if power_status == 'on'
          command_failed, power_output = run_ipmi_command(host_ip, username, passwd, 'power', 'off')
          power_output = power_output.split("\n")
          return [true, /.*(Down\/Off)$/.match(power_output[0])[1]]
        end
        [false, 'Down/Off']
      end

      # A wrapper method for the ipmitool's 'power cycle' command that can be used to power-cycle
      # a node that is currently powered on.  Note that it is an error to try to power-cycle a node
      # that is currently turned off.  You can only power-cycle nodes that are currently powered on.
      #
      # @param (see #power_status)
      # @return [Array<Boolean, String>] an array containing a Boolean indicating whether or not the
      #     'power cycle' command succeeded and a String containing the results of that command
      def power_cycle(host_ip, username, passwd)
        command_failed, power_output = run_ipmi_command(host_ip, username, passwd, 'power', 'status')
        if command_failed
          return [false, power_output]
        end
        power_output = power_output.split("\n")
        power_status = /.*(on|off)$/.match(power_output[0])[1]
        if power_status == 'on'
          command_failed, power_output = run_ipmi_command(host_ip, username, passwd, 'power', 'cycle')
          power_output = power_output.split("\n")
          return [true, /.*(Cycle)$/.match(power_output[0])[1]]
        end
        [false, 'Off']
      end

      # A wrapper method for the ipmitool's 'power reset' command that can be used to perform a hard-reset
      # on a node that is currently powered on.  Note that it is an error to try to perform a hard-reset of
      # a node that is currently turned off.  You can only perform a hard-reset on nodes that are currently
      # powered on.
      #
      # @param (see #power_status)
      # @return [Array<Boolean, String>] an array containing a Boolean indicating whether or not the
      #     'power reset' command succeeded and a String containing the results of that command
      def power_reset(host_ip, username, passwd)
        command_failed, power_output = run_ipmi_command(host_ip, username, passwd, 'power', 'status')
        if command_failed
          return [false, power_output]
        end
        power_output = power_output.split("\n")
        power_status = /.*(on|off)$/.match(power_output[0])[1]
        if power_status == 'on'
          command_failed, power_output = run_ipmi_command(host_ip, username, passwd, 'power', 'reset')
          power_output = power_output.split("\n")
          return [true, /.*(Reset)$/.match(power_output[0])[1]]
        end
        [false, 'Off']
      end

      private

      # A wrapper for the underlying ipmitool system command.  Wraps this command up in a timer
      # ()so that the caller will not wait longer than EXT_COMMAND_TIMEOUT milliseconds for the
      # ipmitool command to return) and handles errors that may be returned by the ipmtool command.
      #
      # @param host_ip [String] the IP address of the BMC to query for 'power status' information
      # @param username [String] the IPMI username to use for the query
      # @param passwd [String] the IPMI password to use for the query
      # @param cmd_and_args [Array<String>] an array of strings containing the command to run
      #     and the arguments to that command; will appear as multiple arguments in the method
      #     call used by the caller
      # @return [Array<Boolean, String>] an array containing a Boolean indicating whether or not the
      #     'ipmitool' command failed (true indicates failure) and a String containing the results
      #     of that command (or the error message if the command failed)
      def run_ipmi_command(host_ip, username, passwd, *cmd_and_args)
        # if the ipmitool command does not exist, need to return an error now
        unless @ipmitool_exists
          return [true, "Command 'ipmitool' does not exist; install ipmitool package and restart server"]
        end
        command_str = cmd_and_args.join(' ')
        command = "ipmitool -I lanplus -H #{host_ip} -U #{username} -P #{passwd} #{command_str} 2>&1"
        begin
          timeout = EXT_COMMAND_TIMEOUT / 1000.0
          Timeout::timeout(timeout) do
            output = %x[#{command}]
            return [true, output] if /Error/.match(output)
            return [false, output]
          end
        rescue Timeout::Error
          return [true, "External Command Timeout (#{EXT_COMMAND_TIMEOUT} msecs) exceeded while executing '#{command}'"]
        rescue Exception => e
          return [true, e.backtrace]
        end
      end

      # Takes the output of the query-style ipmitool commands and converts them to a Hash of name/value
      # pairs (where the names are the properties, as Symbols, and the values are either Strings or arrays of
      # Strings representing the values for those properties)
      # @param ipmi_output [String] the raw output from one of the query-style ipmitool commands
      # @param delimiter [String] the delimiter that should be used to separate the name/value pairs in the
      #     raw ipmitool command output
      # @return [Hash<String, Array<String>>] a Hash map containing the names of the properties as keys and
      #     an Array of String values for that properties as the matching Hash map values.
      def ipmi_output_to_hash(ipmi_output, delimiter)
        array = ipmi_output.split("\n")
        split_hash = Hash.new
        delimiter = "\\#{delimiter}"
        prev_key = nil
        index = 0
        begin
          # grab the next entry
          entry = array[index]
          (index += 1; next) if entry.strip.length == 0
          # parse that entry to obtain the key, first by splitting on the delimiter, then
          # by replacing characters that could be problematic in a symbol with other
          # characters, and finally by converting the key into a symbol
          key_str = entry.split(/\s*#{delimiter}\s?/)[0].strip.gsub(/\s+/," ").gsub(' ','_').gsub('.','').gsub(/^#/,"number")
          # if the key value parsed above is an empty string, then this line contains a value for a
          # key that was parsed earlier
          if key_str.length == 0 && prev_key
            # construct the current value (should be a non-zero-length string)
            val = entry.split(/\s*#{delimiter}\s?/,2)[1].strip
            # grab the value that is mapped to the previous key
            val_to_modify = split_hash[prev_key]
            # if it is an array, simply append a new value to it, else create an array to hold
            # this value and the value mapped to by the prev_key value
            if val_to_modify.is_a?(Array)
              split_hash[prev_key] = (val_to_modify << val)
            else
              new_val = [val_to_modify, val]
              split_hash[prev_key] = new_val
            end
            # and move on to the next line in the array
            index += 1
          else
            key = key_str.to_sym
            # next, split the entry on the delimiter again, this time to determine the value that goes
            # with the key that we just constructed
            entry_array = entry.split(/\s*#{delimiter}\s?/,2)
            # if the length is two, we may or may not have a key-value pair (if the value is an empty string,
            # then we'll have to do a bit more work to get the "value", more on that in a bit)
            if (entry_array.length == 2)
              val = entry.split(/\s*#{delimiter}\s?/,2)[1].strip
              # if the value is non-zero-length string, then are looking at a name/value pair,
              # else if the value is a zero-length string, then assume that we have a set of values
              # in the lines that follow the current entry that contain the values that go with the
              # current key
              if val.length > 0 && index < array.length
                split_hash[key] = val
                index += 1
              elsif index < (array.length - 1)
                val_array = []
                # loop through the next values until hit the end of the array or find an entry
                # that has a length that is not equal to 1
                index += 1
                while index < array.length && (entry_array = array[index].split(/\s*#{delimiter}\s?/,2)).length == 1
                  # strip the single value in the entry_array and add it to the value array
                  val = entry_array[0].strip
                  val_array << val
                  index += 1
                end
                # add the value array as the value for this key in the hash map
                split_hash[key] = val_array
              end
            end
            prev_key = key
          end
        end while index < array.length
        return split_hash
      end

    end
  end
end
