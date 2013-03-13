require "json"
require "yaml"
require "base62"

# time to wait for an external command (in milliseconds)
EXT_COMMAND_TIMEOUT = 2000

# Root ProjectRazor namespace
module ProjectRazor
  class Slice
    # ProjectRazor Slice Bmc
    # Used for all BMC/IPMI logic
    class Bmc < ProjectRazor::Slice
      include(ProjectRazor::Logging)

      # defines the default set of field names that can be used to filter the effects
      # of BMC Slice sub-commands
      DEFAULT_FIELDS_ARRAY = %W[uuid mac ip current_power_state board_serial_number]

      # Initializes ProjectRazor::Slice::Model including #slice_commands, #slice_commands_help, & #slice_name
      # @param args [Array]
      def initialize(args)
        super(args)
        @hidden = false
        @slice_name = "Bmc"
        config = ProjectRazor.config
        @ipmi_username = config.default_ipmi_username
        @ipmi_password = config.default_ipmi_password

        # get the slice commands map for this slice (based on the set
        # of commands that are typical for most slices)
        @slice_commands = get_command_map("bmc_help",
                                          "get_all_bmcs",
                                          "get_bmc_by_uuid",
                                          nil,
                                          "update_bmc_power_state",
                                          nil,
                                          nil)
        # and add any additional commands specific to this slice
        @slice_commands[:register] = "register_bmc"
        @slice_commands[:get][/^(?!^(all|\-\-help|\-h|\{\}|\{.*\}|nil)$)\S+$/][:update] = "update_bmc_power_state"
        @slice_commands[:get][/^(?!^(all|\-\-help|\-h|\{\}|\{.*\}|nil)$)\S+$/][:else] = "get_bmc_by_uuid"
      end

      def bmc_help
        if @prev_args.length > 1
          command = @prev_args.peek(1)
          begin
            # load the option items for this command (if they exist) and print them
            option_items = load_option_items(:command => command.to_sym)
            print_command_help(@slice_name.downcase, command, option_items)
            return
          rescue
          end
        end
        # if here, then either there are no specific options for the current command or we've
        # been asked for generic help, so provide generic help          print_command_help("bmc")
        puts "BMC Slice: used to view the current list of BMCs; also used by to register".red
        puts "    new BMCs with Razor.".red
        puts "BMC Commands:".yellow
        puts "\trazor bmc [get] [all]                             " + "Display list of BMCs".yellow
        puts "\trazor bmc [get] (UUID) [--query,-q (IPMI_QUERY)]  " + "Display info for a BMC".yellow
        puts "\trazor bmc register (options...)                   " + "Registers a new BMC".yellow
        puts "\trazor bmc update (UUID) --power-state,-p (STATE)  " + "Set power state using BMC".yellow
        puts "  Note; the IPMI_QUERY value passed via the --query flag be one of (info, guid,".red
        puts "        enables, fru_print, lan_print, chassis_status, or power_status), while".red
        puts "        the STATE passed via the --power-state flag can be one of (on, off,".red
        puts "        cycle, or reset)".red
      end

      # This function is used to print out an array of all of the Bmc nodes in a tabular form
      # (using the centralized print_object_array method)
      def get_all_bmcs
        @command = :get_all_bmcs
        # if it's a web command and the last argument wasn't the string "default" or "get", then a
        # filter expression was included as part of the web command
        @command_array.unshift(@prev_args.pop) if @web_command && @prev_args.peek(0) != "default" && @prev_args.peek(0) != "get"
        bmc_array = get_object("bmc", :bmc)
        if bmc_array
          bmc_array.each { |bmc|
            bmc.refresh_power_state
          }
        end
        print_object_array bmc_array, "Bmc Nodes"
      end

      # This function is used to print out a single matching BMC object (where the match
      # is made based on the UUID value passed into the function)
      def get_bmc_by_uuid
        @command = :get_bmc_by_uuid
        includes_uuid = false
        # load the appropriate option items for the subcommand we are handling
        option_items = load_option_items(:command => :get)
        # parse and validate the options that were passed in as part of this
        # subcommand (this method will return a UUID value, if present, and the
        # options map constructed from the @commmand_array)
        @command_array.unshift(@prev_args.pop) if @web_command
        bmc_uuid, options = parse_and_validate_options(option_items, "razor bmc [get] (UUID) [--query,-q IPMI_QUERY]", :require_all)
        includes_uuid = true if bmc_uuid
        matching_bmc = get_bmc_with_uuid(bmc_uuid)
        raise ProjectRazor::Error::Slice::InvalidUUID, "no matching BMC (with a uuid value of '#{bmc_uuid}') found" unless matching_bmc
        selected_option = options[:query]
        # if no options were passed in, then just print out the summary for the specified bmc
        return print_object_array [matching_bmc], "Bmc Nodes" unless selected_option
        # else, show the result of running the appropriate impitool query command
        if selected_option == "power_status"
          run_ipmi_query_cmd(bmc_uuid, "power", "status")
        elsif selected_option == "lan_print"
          run_ipmi_query_cmd(bmc_uuid, "lan", "print")
        elsif selected_option == "fru_print"
          run_ipmi_query_cmd(bmc_uuid, "fru", "print")
        else
          run_ipmi_query_cmd(bmc_uuid, "get", selected_option)
        end
      end

      # This function searches for a Bmc node that matches the '@uuid' value contained
      # in the single input argument to the function.  It then refreshes the current power
      # state of that Bmc object and returns it to the caller
      #
      # @param [String] uuid
      # @return [ProjectRazor::PowerControl::Bmc]
      def get_bmc_with_uuid(uuid)
        setup_data
        existing_bmc = get_object("bmc_instance", :bmc, uuid)
        existing_bmc.refresh_power_state if existing_bmc && (existing_bmc.class != Array || existing_bmc.length > 0)
        existing_bmc
      end

      def update_bmc_power_state
        @command = :update_bmc_power_state
        includes_uuid = false
        # load the appropriate option items for the subcommand we are handling
        option_items = load_option_items(:command => :update)
        # parse and validate the options that were passed in as part of this
        # subcommand (this method will return a UUID value, if present, and the
        # options map constructed from the @commmand_array)
        bmc_uuid, options = parse_and_validate_options(option_items, "razor bmc update UUID --power-state,-p NEW_STATE", :require_one)
        includes_uuid = true if bmc_uuid
        # check for usage errors (the boolean value at the end of this method
        # call is used to indicate whether the choice of options from the
        # option_items hash must be an exclusive choice)
        check_option_usage(option_items, options, includes_uuid, true)
        new_state = options[:power_state]
        change_bmc_power_state(bmc_uuid, new_state)
      end

      # This function is used to registers a BMC with Razor (or to change the values associated
      # with an existing BMC in the Razor database)
      def register_bmc
        @command = :register_bmc
        # load the appropriate option items for the subcommand we are handling
        option_items = load_option_items(:command => :register)
        # parse and validate the options that were passed in as part of this
        # subcommand (this method will return a UUID value, if present, and the
        # options map constructed from the @commmand_array)
        tmp, options = parse_and_validate_options(option_items, "razor bmc register (options...)", :require_all)
        includes_uuid = true if tmp && tmp != "register"
        # check for usage errors (the boolean value at the end of this method
        # call is used to indicate whether the choice of options from the
        # option_items hash must be an exclusive choice)
        check_option_usage(option_items, options, includes_uuid, false)
        # bmc_uuid = options[:uuid]
        mac_addr = options[:mac_address]
        bmc_uuid = mac_addr.tr(":","").reverse.to_i(base=16).base62_encode
        ip_addr = options[:ip_address]

        begin
          # if we have the details we need, then insert this bmc into the database (or
          # update the matching bmc object, if one exists, otherwise, raise an exception)
          # raise ProjectRazor::Error::Slice::MissingArgument, "cannot register BMC without specifying the uuid, mac, and ip" unless bmc_uuid && mac_addr && ip_addr
          logger.debug "bmc: #{mac_addr} #{ip_addr}"
          timestamp = Time.now.to_i
          bmc_hash = {"@uuid" => bmc_uuid,
                      "@mac" => mac_addr,
                      "@ip" => ip_addr,
                      "@current_power_state" => @current_power_state,
                      "@board_serial_number" => @board_serial_number,
                      "@timestamp" => timestamp}
          new_bmc = insert_bmc(bmc_hash)
          raise ProjectRazor::Error::Slice::CouldNotRegisterBmc, "failed to refresh BMC state" unless new_bmc
          update_success = new_bmc.refresh_self
          raise ProjectRazor::Error::Slice::InternalError, "failed to refresh BMC state" unless update_success
          slice_success(new_bmc.to_hash)
        rescue ProjectRazor::Error::Slice::Generic => e
          raise e
        rescue StandardError => e
          raise ProjectRazor::Error::Slice::InternalError, "error occurred while inserting BMC " + e.message
        end
      end

      # This function is the handler for all of the IPMI-style queries against the underlying bmc node
      # This method is invoked by all of the commands in the @slice_commands map that query the underlying
      # BMC on a node for information about that node
      def run_ipmi_query_cmd(bmc_uuid, sub_command, sub_command_action)
        ipmitool_cmd = map_to_ipmitool_cmd(sub_command, sub_command_action)
        begin
          bmc = get_bmc_with_uuid(bmc_uuid)
          raise ProjectRazor::Error::Slice::InvalidUUID, "no matching BMC (with a uuid value of '#{bmc_uuid}') found" unless bmc
          command_success, output = bmc.run_ipmi_query_cmd(ipmitool_cmd, @ipmi_username, @ipmi_password)
          # handle the returned values;
          # throw an error if the command failed to execute properly
          raise ProjectRazor::Error::Slice::InvalidCommand,
                "ipmi query command '#{ipmitool_cmd}' failed" unless command_success
        rescue ProjectRazor::Error::Slice::Generic => e
          raise e
        rescue StandardError => e
          raise ProjectRazor::Error::Slice::InternalError,
                "error occurred while executing ipmi query command #{ipmitool_cmd} -> #{e.message}"
        end
      end

      # This function is the handler for changing power state of a bmc node to a new state.
      # This method is invoked by all of the commands in the @slice_commands map that make
      # changes to the power-state of the node
      def change_bmc_power_state(bmc_uuid, new_state)
        raise ProjectRazor::Error::Slice::InvalidCommand, "missing details for command to change power state" unless
            new_state && new_state.length > 0
        begin
          raise ProjectRazor::Error::Slice::MissingArgument, "missing the uuid value for command to change power state" unless bmc_uuid
          logger.debug "Changing power-state of bmc: #{bmc_uuid} to #{new_state}"
          bmc = get_bmc_with_uuid(bmc_uuid)
          raise ProjectRazor::Error::Slice::InvalidUUID, "no matching BMC (with a uuid value of '#{bmc_uuid}') found" unless bmc
          power_state_changed, status_string = bmc.change_power_state(new_state, @ipmi_username, @ipmi_password)
          # handle the returned values; how the returned values should be handled will vary
          # depending on the "new_state" that the node is being transitioned into.  For example,
          # you can only turn on a node that is off (or turn off a node that is on), but it
          # isn't an error to turn on a node that is already on (or turn off a node that is
          # already off) since that operation is, in effect, a no-op.  On the other hand,
          # it is an error to try to power-cycle or reset a node that isn't already on, since
          # these operations don't make any sense on a powered-off node.
          result_string = ""
          if new_state == "on"
            if power_state_changed && /Up\/On/.match(status_string)
              # success condition
              result_string = "node '#{bmc_uuid}' now powering on"
            elsif !power_state_changed && /Up\/On/.match(status_string)
              # success condition
              result_string = "node '#{bmc_uuid}' already powered on"
            else
              # error condition
              result_string = "attempt to power on node '#{bmc_uuid}' failed"
            end
            raise ProjectRazor::Error::Slice::CommandFailed, result_string unless
                power_state_changed && /Up\/On/.match(status_string) ||
                    !power_state_changed && /Up\/On/.match(status_string)
          elsif new_state == "off"
            if power_state_changed && /Down\/Off/.match(status_string)
              # success condition
              result_string = "node '#{bmc_uuid}' now powering off"
            elsif !power_state_changed && /Down\/Off/.match(status_string)
              # success condition
              result_string = "node '#{bmc_uuid}' already powered off"
            else
              # error condition
              result_string = "attempt to power off node '#{bmc_uuid}' failed"
            end
            raise ProjectRazor::Error::Slice::CommandFailed, result_string unless
                power_state_changed && /Down\/Off/.match(status_string) ||
                    !power_state_changed && /Down\/Off/.match(status_string)
          elsif new_state == "cycle"
            if power_state_changed && /Cycle/.match(status_string)
              # success condition
              result_string = "node '#{bmc_uuid}' now power cycling"
            elsif !power_state_changed && /Off/.match(status_string)
              # error condition
              result_string = "node '#{bmc_uuid}' powered off, cannot power cycle"
            else
              # error condition
              result_string = "attempt to power cycle node '#{bmc_uuid}' failed"
            end
            raise ProjectRazor::Error::Slice::CommandFailed, result_string unless
                power_state_changed && /Cycle/.match(status_string)
          elsif new_state == "reset"
            if power_state_changed && /Reset/.match(status_string)
              # success condition
              result_string = "node '#{bmc_uuid}' now powering off"
            elsif !power_state_changed && /Off/.match(status_string)
              # error condition
              result_string = "node '#{bmc_uuid}' powered off, cannot reset"
            else
              # error condition
              result_string = "attempt to reset node '#{bmc_uuid}' failed"
            end
            raise ProjectRazor::Error::Slice::CommandFailed, result_string unless
                power_state_changed && /Reset/.match(status_string)
          else
            raise ProjectRazor::Error::Slice::CommandFailed, "Unrecognized new_state '#{new_state}'; must be one of (on|off|cycle|reset)"
          end
          slice_success(result_string)
        rescue ProjectRazor::Error::Slice::Generic => e
          raise e
        rescue StandardError => e
          raise ProjectRazor::Error::Slice::InternalError, "an error occurred while changing power state -> #{e.message}"
        end
      end

      # This function updates the '@current_power_state' and '@board_serial_number' fields in
      # the input bmc_hash Hash Map (using run_ipmi_query calls to the underlying
      # ProjectRazor::PowerControl::Bmc object to fill in correct values for the board_serial_number
      # and current_power_state).  The bmc_hash is modified during the call and, as a result,
      # it contains the correct current values for these two fields when control is returned to the
      # caller
      #
      # @param [ProjectRazor::PowerControl::Bmc] bmc
      # @param [Hash] bmc_hash
      def update_bmc_hash!(bmc, bmc_hash)
        # values to return if the ipmitool command does not succeed
        bmc_hash["@current_power_state"] = "unknown"
        bmc_hash["@board_serial_number"] = ''
        # now, invoke run the ipmitool commands needed to get the current-power-state and
        # board-serial-number for this bmc node
        command_success, power_state = bmc.run_ipmi_query_cmd("power_status", @ipmi_username, @ipmi_password)
        bmc_hash["@current_power_state"] = power_state if command_success
        command_success, fru_hash = bmc.run_ipmi_query_cmd("fru_print", @ipmi_username, @ipmi_password)
        bmc_hash["@board_serial_number"] = fru_hash[:Board_Serial] if command_success
      end

      # This function is used to inserts a new Bmc object into the database (or updates a matching
      # Bmc object in the database where the match is determined based on uuid values) using the
      # bmc_hash as input.  There are three possible outcomes from this method:
      #
      #     1. If there is a node who's uuid value matches that found in the '@uuid' field of the
      #        bmc_hash, and if the meta-data contained in that object ('@mac', '@ip', '@current_power_state',
      #        or '@board_serial_number') differ from those found in the bmc_hash, then that object
      #        is updated in the database, and the updated object is returned to the caller
      #     2. If there is no matching object (by uuid), then a new object is created using the bmc_hash
      #        as input, that new object is persisted to the database, and the new object is returned
      #        to the caller
      #     3. If there is a matching object but the meta-data values it contains are the same as those
      #        found in the bmc_hash object, then the matching object is returned to the caller unchanged.
      #
      # @param [Hash] bmc_hash
      # @return [ProjectRazor::PowerControl::Bmc]
      def insert_bmc(bmc_hash)
        setup_data
        bmc = @data.fetch_object_by_uuid(:bmc, bmc_hash['@uuid'])
        # if we have a matching BMC already in the database with that name
        if bmc != nil
          # and if the details in the bmc_hash are different from the details
          # for the BMC in object in the database, then update the database object
          # to match the details in the bmc_hash
          if (bmc.mac != bmc_hash['@mac'] || bmc.ip != bmc_hash['@ip'] ||
              bmc.current_power_state != bmc_hash['@current_power_state'] ||
              bmc.board_serial_number != bmc_hash['@board_serial_number'])
            bmc.mac = bmc_hash['@mac']
            bmc.ip = bmc_hash['@ip']
            # values to use if the ipmitool commands fail for some reason
            bmc.current_power_state = "unknown"
            bmc.board_serial_number = ''
            # now, invoke run the ipmitool commands needed to get the current-power-state and
            # board-serial-number for this bmc node
            command_success, power_state = bmc.run_ipmi_query_cmd("power_status", @ipmi_username, @ipmi_password)
            bmc.current_power_state = power_state if command_success
            command_success, fru_hash = bmc.run_ipmi_query_cmd("fru_print", @ipmi_username, @ipmi_password)
            bmc.board_serial_number = fru_hash[:Board_Serial] if command_success
            bmc.update_self
          end
        else
          # else, if there is no matching BMC object in the database, add a new object
          # using the contents of the bmc_hash as input (and setting the current_power_state
          # and board_serial number to values gathered usign the corresponding IPMI queries)
          bmc = ProjectRazor::PowerControl::Bmc.new(bmc_hash)
          begin
            command_success, power_state = bmc.run_ipmi_query_cmd("power_status", @ipmi_username, @ipmi_password)
            bmc.current_power_state = power_state if status_flag
            command_success, fru_hash = bmc.run_ipmi_query_cmd("fru_print", @ipmi_username, @ipmi_password)
            bmc.board_serial_number = fru_hash[:Board_Serial] if status_flag
          rescue => e
            bmc.current_power_state = "unknown"
            bmc.board_serial_number = ''
          end
          @data.persist_object(bmc)
        end
        bmc
      end

      # This function is used to map the combination of a sub_command and an action on
      # that sub_command into an "ipmitool_cmd" string value.  Valid sub_command/action
      # combinations (and the ipmitool_cmd they map into) are as follows:
      #
      # lan or fru -> print
      # power, status => power_status
      # get, info => bmc_info
      # get, enables => bmc_getenables
      # get, guid => bmc_guid
      # get, chassis_status => chassis_status
      # lan, print => lan_print
      # fru, print => fru_print
      #
      # the resulting string is returned to the caller for later use (this maps our new
      # actions into the old actions quite effectively, reducing the number of commands
      # needed in this slice and allowing for us to use the old BMC backing object with
      # the new BMC slice, but without having to make any changes to the backing object)
      def map_to_ipmitool_cmd(sub_command, sub_command_action)
        case "#{sub_command}, #{sub_command_action}"
          when "power, status"
            return "power_status"
          when "get, info"
            return "bmc_info"
          when "get, enables"
            return "bmc_getenables"
          when "get, guid"
            return "bmc_guid"
          when "get, chassis_status"
            return "chassis_status"
          when "lan, print"
            return "lan_print"
          when "fru, print"
            return "fru_print"
          else
            raise ProjectRazor::Error::Slice::SliceCommandParsingFailed,
                  "the BMC sub-command '#{sub_command} #{sub_command_action}' is not recognized"
        end
      end

    end
  end
end
