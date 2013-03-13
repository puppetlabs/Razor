# ProjectRazor Policy Base class
# Root abstract

module ProjectRazor
  module PowerControl
    class Bmc < ProjectRazor::Object
      # used to store/access the MAC address of the underlying BMC's NIC
      attr_accessor :mac
      # used to store/access the IP address assigned to the underlying BMC's NIC
      attr_accessor :ip
      # used to store/access the Current Power State of the underlying BMC
      attr_accessor :current_power_state
      # used to store/access the Board Serial Number of node attached to the underlying BMC
      attr_accessor :board_serial_number

      # @param hash [Hash]
      def initialize(hash = nil)
        super()
        @_namespace = :bmc
        @noun = "bmc"
        @current_power_state = "unknown"
        @board_serial_number = ''
        from_hash(hash) unless hash == nil
        @_ipmi = ProjectRazor::PowerControl::IpmiController.instance
        config = ProjectRazor.config
        @_ipmi_username = config.default_ipmi_username
        @_ipmi_password = config.default_ipmi_password
      end

      # Returns a reference to the current Bmc node with the current_power_state set to
      # the current value for that node.  Also ensures that any changes in this state
      # are persisted to the database
      # @return [Bmc]
      def refresh_power_state
        # values to return if the ipmitool command does not succeed
        @current_power_state = "unknown"
        # now, invoke run the ipmitool commands needed to get the current-power-state and
        # board-serial-number for this bmc node
        command_success, power_state = run_ipmi_query_cmd("power_status", @_ipmi_username, @_ipmi_password)
        @current_power_state = power_state if command_success
        self.update_self
      end

      # Returns a reference to the current Bmc node with the board_serial_number set to
      # the current value for that node.  Also ensures that any changes in this serial number
      # are persisted to the database
      # @return [Bmc]
      def refresh_board_serial_number
        # values to return if the ipmitool command does not succeed
        @board_serial_number = ""
        # now, invoke run the ipmitool commands needed to get the current-power-state and
        # board-serial-number for this bmc node
        command_success, fru_hash = run_ipmi_query_cmd("fru_print", @_ipmi_username, @_ipmi_password)
        @board_serial_number = fru_hash[:Board_Serial] if command_success
        self.update_self
      end

      # Used to change the power state of this node via the IPMI interface provided by the BMC.
      #
      # @param new_state [String] the desired state; should be one 'on', 'off', 'cycle', or 'reset' to
      #     power the node on, power the node off, power-cycle the node or perform a hard-reset of the
      #     node (respectively)
      # @param username [String] the username that should be used to access the BMC via it's IPMI interface
      # @param password [String] the password that should be used to access the BMC via it's IPMI interface
      # @return [Array<Boolean, String>] an array containing a Boolean showing whether or not the command
      #     succeeded (true indicates success) and a String containing the command results
      def change_power_state(new_state, username, password)
        case new_state
          when new_state = "on"
            return @_ipmi.power_on(@ip, username, password)
          when new_state = "off"
            return @_ipmi.power_off(@ip, username, password)
          when new_state = "cycle"
            return @_ipmi.power_cycle(@ip, username, password)
          when new_state = "reset"
            return @_ipmi.power_reset(@ip, username, password)
          else
            return [false, "Unrecognized power-state #{new_state}; acceptable values are on, off, cycle, or reset"]
        end
      end

      # Used to change the power state of this node via the IPMI interface provided by the BMC.
      #
      # @param new_state [String] the desired state; should be one 'on', 'off', 'cycle', or 'reset' to
      #     power the node on, power the node off, power-cycle the node or perform a hard-reset of the
      #     node (respectively)
      # @param username [String] the username that should be used to access the BMC via it's IPMI interface
      # @param password [String] the password that should be used to access the BMC via it's IPMI interface
      # @return [Array<Boolean, Hash>] an array containing a Boolean showing whether or not the command
      #     succeeded (true indicates success) and a Hash map containing the command results (a list of
      #     properties expressed as name/value pairs where the names are Symbols and the values are Strings
      #     or arrays of Strings)
      def run_ipmi_query_cmd(cmd, username, password)
        case cmd
          when "power_status"
            return @_ipmi.power_status(@ip, username, password)
          when "bmc_info"
            return @_ipmi.bmc_info(@ip, username, password)
          when "bmc_getenables"
            return @_ipmi.bmc_getenables(@ip, username, password)
          when "bmc_guid"
            return @_ipmi.bmc_guid(@ip, username, password)
          when "chassis_status"
            return @_ipmi.chassis_status(@ip, username, password)
          when "lan_print"
            return @_ipmi.lan_print(@ip, username, password)
          when "fru_print"
            return @_ipmi.fru_print(@ip, username, password)
          else
            return [false, "Unrecognized query command #{cmd}; acceptable values are power_status," +
                " bmc_info, bmc_getenables, bmc_guid, chassis_status, lan_print or fru_print"]
        end
      end

      # This method is required by the common printing framework to support the printing of an array
      # of Bmc objects.  It is used to specify the values that should be used for the column headings
      # when printing the array in tabular form.
      # @return [String] a string containing the values to use for the column headings
      def print_header
        return "MAC-Addr", "IP-Addr", "Power", "S/N", "UUID"
      end

      # This method is required by the common printing framework to support the printing of
      # an array of Bmc objects.  It is used to specify the fields that should be printed for
      # each Bmc object when printing the array in tabular form
      # @return [Array<String>] an array containing the fields that should be printed
      #       for this object
      def print_items
        return @mac, @ip, @current_power_state, @board_serial_number, @uuid
      end

      # This method is required by the common printing framework to support the printing of an array
      # of Bmc objects.  It is used to specify the color that should be used when printing the meta-data
      # for each object in the array.  In this case, we change the color on a per-object basis (based
      # on the value of the '@current_power_state' value) as follows:
      #
      #     'on'      => returns :green
      #     'off'     => returns :red
      #     'unknown' => returns :yellow
      #
      # @return [Symbol] the value for the color that should be used to print the
      #     meta-data for this object
      def line_color
        case @current_power_state
          when "on"
            return :green
          when "off"
            return :red
          else
            return :yellow
        end
      end

      # This method is required by the common printing framework to support the printing of an array
      # of Bmc objects.  It is used to specify the color that should be used when printing
      # the header row for the table containing the meta-data for the array.
      #
      # @return [Symbol] the value for the color that should be used to print the column
      #     headings when printing an array of Bmc objects
      def header_color
        #:blue
      end

    end
  end
end
