require "json"

module ProjectRazor
  module SliceUtil
    module Common

      # here, we define a Stack class that simply delegates the equivalent "push", "pop",
      # "to_s" and "clear" calls to the underlying Array object using the delegation
      # methods provided by Ruby through the Forwardable class.  We could do the same
      # thing using an Array, but that wouldn't let us restrict the methods that
      # were supported by our Stack to just those methods that a stack should have

      require "forwardable"

      class Stack
        extend Forwardable
        def_delegators :@array, :push, :pop, :to_s, :clear, :count

        # initializes the underlying array for the stack
        def initialize
          @array = []
        end

        # looks at the last element pushed onto the stack
        def look
          @array.last
        end

        # peeks down to the n-th element in the stack (zero is the top,
        # if the 'n' value that is passed is deeper than the stack, it's
        # an error (and will result in an IndexError being thrown)
        def peek(n = 0)
          stack_idx = -(n+1)
          @array[stack_idx]
        end

        def size
          @array.size
        end

        def length
          @array.length
        end

        def include?(val)
          @array.include?(val)
        end

        def join(sep)
          @array.join(sep)
        end

      end

      # This allows stubbing
      def command_shift
        @command_array.shift
      end

      def get_web_vars(vars_array)
        begin
          vars_hash = sanitize_hash(JSON.parse(command_shift))
          vars_array.collect { |k| vars_hash[k] if vars_hash.has_key? k }
        rescue JSON::ParserError
          # TODO: Determine if logging appropriate
          return nil
        rescue Exception => e
          # TODO: Determine if throwing exception appropriate
          raise e
        end
      end

      # This allows stubbing
      def command_array
        @command_array
      end

      def get_cli_vars(vars_array)
        vars_hash = Hash[command_array.collect { |x| x.split("=") }]
        vars_array.collect { |k| vars_hash[k] if vars_hash.has_key? k }
      end

      def get_options(options = { }, optparse_options = { })
        optparse_options[:banner] ||= "razor [command] [options...]"
        OptionParser.new do |opts|
          opts.banner = optparse_options[:banner]
          optparse_options[:options_items].each do |opt_item|
            options[opt_item[:name]] = opt_item[:default]
            opts.on(opt_item[:short_form], opt_item[:long_form], "#{opt_item[:description]} #{" - required" if opt_item[:required] && optparse_options[:list_required]}") do |param|
              options[opt_item[:name]] = param ? param : true
            end
          end
          opts.on('-h', '--help', 'Display this screen.') do
            print "Usage: "
            puts opts
            exit
          end
        end
      end

      def get_options_web
        begin
          return Hash[sanitize_hash(JSON.parse(command_shift)).map { |(k, v)| [k.to_sym, v] }]
        rescue JSON::ParserError => e
          # TODO: Determine if logging appropriate
          puts e.message
          return {}
        rescue Exception => e
          # TODO: Determine if throwing exception appropriate
          raise e
        end
      end

      def validate_options(validate_options = { })
        #validate_options[:logic] ||= :require_all
        validate_options[:logic] ||= :require_none
        option_names = validate_options[:options].map { |key, value| key }
        case validate_options[:logic]
          when :require_one
            count = 0
            validate_options[:option_items].each do
            |opt_item|
              count += 1 if opt_item[:required] && validate_arg(validate_options[:options][opt_item[:name]])
            end
            raise ProjectRazor::Error::Slice::MissingArgument, "Must provide one option from #{option_names.inspect}." if count < 1
          when :require_all
            validate_options[:option_items].each do
            |opt_item|
              raise ProjectRazor::Error::Slice::MissingArgument, "Must Provide: [#{opt_item[:description]}]" if opt_item[:required] && !validate_arg(validate_options[:options][opt_item[:name]])
            end
        end

      end

      # Returns all child templates from prefix
      def get_child_templates(namespace)
        if [Symbol, String].include? namespace.class
          namespace.gsub!(/::$/, '') if namespace.is_a? String
          namespace = ::Object.full_const_get namespace
        end

        namespace.class_children.map do |child|
          new_object             = child.new({ })
          new_object.is_template = true
          new_object
        end.reject do |object|
          object.hidden
        end
      end

      alias :get_child_types :get_child_templates

      # Checks to make sure an arg is a format that supports a noun (uuid, etc))
      def validate_arg(*arg)
        arg.each do |a|
          return false unless a && (a.to_s =~ /^\{.*\}$/) == nil && a != '' && a != {}
        end
      end

      # used by slices to parse and validate the options for a particular subcommand
      def parse_and_validate_options(option_items, banner, logic = nil)
        options = {}
        #uuid = @web_command ? @prev_args.peek(1) : @prev_args.peek(0)
        uuid = @prev_args.peek(0)
        # Get our optparse object passing our options hash, option_items hash, and our banner
        optparse = get_options(options, :options_items => option_items, :banner => banner)
        # set the command help text to the string output from optparse
        @command_help_text << optparse.to_s
        # if it's a web command, get the web options that were passed
        if @web_command
          options = get_options_web
        end
        # parse our ARGV with the optparse unless options are already set from get_options_web
        optparse.parse! unless option_items.any? { |k| options[k] }
        # validate required options, we use the :require_one logic to check if at least one :required value is present
        validate_options(:option_items => option_items, :options => options, :logic => logic)
        return uuid, options
      end

      # used by the slices to print out detailed usage for individual commands
      def print_command_help(slice_name, command, option_items, contained_resource = nil)
        banner = ""
        if contained_resource
          banner = ( option_items.select { |elem| elem[:uuid_is] == "required" }.length > 0 ?
              "razor #{slice_name} (#{slice_name.upcase}_UUID) #{contained_resource} #{command} (UUID) (options...)" :
              "razor #{slice_name} (#{slice_name.upcase}_UUID) #{contained_resource} #{command} (options...)")
        else
          banner = ( option_items.select { |elem| elem[:uuid_is] == "required" }.length > 0 ?
              "razor #{slice_name} #{command} (UUID) (options...)" :
              "razor #{slice_name} #{command} (options...)")
        end
        usage_lines = get_options({}, :options_items => option_items,
                                  :banner => banner).to_s.split("\n")
        if usage_lines
          puts "Usage: #{usage_lines[0]}"
          usage_lines[1..usage_lines.size].each { |line|
            puts line
          } if usage_lines.length > 1
        end
      end

      # used by slices to ensure that the usage of options for any given
      # subcommand is consistent with the usage declared in the option_items
      # Hash map for that subcommand
      def check_option_usage(option_items, options, uuid_included, exclusive_choice)
        selected_option_names = options.keys
        selected_options = option_items.select{ |item| selected_option_names.include?(item[:name]) }
        if exclusive_choice && selected_options.length > 1
          # if it's an exclusive choice and more than one option was chosen, it's an error
          raise ProjectRazor::Error::Slice::SliceCommandParsingFailed,
                "Only one of the #{options.map { |key, val| key }.inspect} flags may be used"
        end
        # check all of the flags that were passed to see if the UUID was included
        # if it's required for that flag (and if it was not if it is not allowed
        # for that flag)
        selected_options.each { |selected_option|
          if (!uuid_included && selected_option[:uuid_is] == "required")
            raise ProjectRazor::Error::Slice::SliceCommandParsingFailed,
                  "Must specify a UUID value when using the '#{selected_option[:name]}' option"
          elsif (uuid_included &&  selected_option[:uuid_is] == "not_allowed")
            raise ProjectRazor::Error::Slice::SliceCommandParsingFailed,
                  "Cannot specify a UUID value when using the '#{selected_option[:name]}' option"
          end
        }
      end

      # used by the slices to retrieve the UUID value from a set of previous arguments
      # (assumes that the UUID and, potentially one more argument if it's a web command
      # appear as the first two arguments in the @prev_args stack)
      def get_uuid_from_prev_args
        @web_command && @prev_args.peek(0) == '{}' ? @prev_args.peek(1) : @prev_args.peek(0)
      end

      # used by the slices to throw an error when an error occurred while attempting to parse
      # a slice command line
      def throw_syntax_error
        command_str = "razor #{@slice_name.downcase} #{@prev_args.join(" ")}"
        command_str << " " + @command_array.join(" ") if @command_array && @command_array.length > 0
        raise ProjectRazor::Error::Slice::SliceCommandParsingFailed,
              "failed to parse slice command: '#{command_str}'; check usage"
      end

      # used by the slices to throw an error when an unexpected UUID was found
      # while parsing the command line
      def throw_uuid_not_allowed_error
        raise ProjectRazor::Error::Slice::SliceCommandParsingFailed,
              "Unexpected UUID argument found; a UUID value is not allowed in this command"
      end

      # used by the slices to throw an error when a UUID was expected in a slice command
      # but no UUID value was found
      def throw_missing_uuid_error
        raise ProjectRazor::Error::Slice::MissingArgument,
              "Expected UUID argument missing; a UUID is required for this command"
      end

      # used by slices to support an error indicating that an operation is not
      # supported by that slice
      def throw_get_by_uuid_not_supported
        raise ProjectRazor::Error::Slice::NotImplemented,
        "there is no 'get_by_uuid' operation defined for the #{@slice_name} slice"
      end

      # used by slices to construct a typical @slice_command hash map based on
      # an input set of function names
      def get_command_map(help_cmd_name, get_all_cmd_name, get_by_uuid_cmd_name,
          add_cmd_name, update_cmd_name, remove_all_cmd_name, remove_by_uuid_cmd_name)
        return_all = ["all", '{}', /^\{.*\}$/, nil]
        cmd_map = {}
        get_all_cmd_name = "throw_missing_uuid_error" unless get_all_cmd_name
        remove_all_cmd_name = "throw_missing_uuid_error" unless remove_all_cmd_name
        get_by_uuid_cmd_name = "throw_get_by_uuid_not_supported" unless get_by_uuid_cmd_name
        raise ProjectRazor::Error::Slice::MissingArgument,
              "A 'help_cmd_name' parameter must be included" unless help_cmd_name

        # add a get action if non-nil values for the get-related command names
        # were included in the input arguments
        cmd_map[:get] = {
            return_all                      => get_all_cmd_name,
            :default                        => get_all_cmd_name,
            ["--help", "-h"]                => help_cmd_name,
            /^(?!^(all|\-\-help|\-h|\{\}|\{.*\}|nil)$)\S+$/ => {
                [/^\{.*\}$/]                    => get_by_uuid_cmd_name,
                :default                        => get_by_uuid_cmd_name,
                :else                           => "throw_syntax_error"
            }
        } if (get_all_cmd_name && get_by_uuid_cmd_name)
        # add an add action if a non-nil value for the add_cmd_name parameter
        # was included in the input arguments
        cmd_map[:add] = {
            :default         => add_cmd_name,
            :else            => add_cmd_name,
            ["--help", "-h"] => help_cmd_name
        } if add_cmd_name
        # add an update action if a non-nil value for the update_cmd_name
        # parameter names was included in the input arguments
        cmd_map[:update] = {
            :default                        => "throw_missing_uuid_error",
            ["--help", "-h"]                => help_cmd_name,
            /^(?!^(all|\-\-help|\-h)$)\S+$/ => {
                :else                           => update_cmd_name,
                :default                        => update_cmd_name
            }
        } if update_cmd_name
        # add an update action if a non-nil value for the remove_cmd_name
        # parameter names was included in the input arguments
        cmd_map[:remove] = {
            ["all"]                         => remove_all_cmd_name,
            :default                        => "throw_missing_uuid_error",
            ["--help", "-h"]                => help_cmd_name,
            /^(?!^(all|\-\-help|\-h)$)\S+$/ => {
                [/^\{.*\}$/]                    => remove_by_uuid_cmd_name,
                :else                           => "throw_syntax_error",
                :default                        => remove_by_uuid_cmd_name
            }
        } if (remove_all_cmd_name && remove_by_uuid_cmd_name)
        # add a few more elements that are common between slices
        cmd_map[:default] = :get
        cmd_map[:else] = :get
        cmd_map[["--help", "-h"]] = help_cmd_name
        # and return the result
        cmd_map
      end

      # Gets a selection of objects for slice
      # @param noun [String] name of the object for logging
      # @param collection [Symbol] collection for object

      def get_object(noun, collection, uuid = nil)
        logger.debug "Query #{noun} called"

        # If uuid provided just grab and return
        if uuid
          return return_objects_using_uuid(collection, uuid)
        end

        # Check if REST-driven request
        if @web_command
          # Get request filter JSON string
          @filter_json_string = @command_array.shift
          @filter_json_string = '{}' if @filter_json_string == 'null' # handles bad PUT requests
                                                                      # Check if we were passed a filter string
          if @filter_json_string != "{}" && @filter_json_string != nil
            @command = "query_with_filter"
            begin
              # Render our JSON to a Hash
              filter_hash = JSON.parse(@filter_json_string)
              # if any of the Hash values are "true" or "false", convert to equivalent
              # Boolean values (true and false, respectively)
              filter_hash.each { |key, val|
                (filter_hash[key] = true; next) if val == "true"
                filter_hash[key] = false if val == "false"
              }
              return return_objects_using_filter(filter_hash, collection)
            rescue StandardError => e
              # We caught an error / likely JSON. We return the error text as a Slice error.
              slice_error(e.message, false)
            end
          else
            @command = "#{noun}_query_all"
            return return_objects(collection)
          end
          # Is CLI driven
        else
          return_objects(collection)
        end
      end

      # Return objects using a filter
      # @param filter [Hash] contains key/values used for filtering
      # @param collection [Symbol] collection symbol
      def return_objects_using_filter(collection, filter_hash)
        setup_data
        @data.fetch_objects_by_filter(filter_hash, collection)
      end

      # Return all objects (no filtering)
      def return_objects(collection)
        setup_data
        @data.fetch_all_objects(collection)
      end

      # Return objects using uuid
      # @param filter [Hash] contains key/values used for filtering
      # @param collection [Symbol] collection symbol
      def return_objects_using_uuid(collection, uuid)
        setup_data
        @data.fetch_object_by_uuid_pattern(collection, uuid)
      end


      # used to parse a set of name-value command-line arguments received
      # as arguments to a slice "sub-command" and return those values to the
      # caller.  If specified, the "expected_names" field can be used to restrict
      # the names parsed to just those that are expected (useful for restricting
      # the name/value pairs to just those that are "expected")
      #
      # @param [Object] expected_names  An array containing a list of field names
      # to return (in the order in which they should be returned).  Any fields not
      # in this list will result in an error being thrown by this method.
      # @return [Hash] name/value pairs parsed from the command-line
      def get_name_value_args(expected_names = nil)
        # initialize the return values (to nil) by pre-allocating an appropriately size array
        return_vals = { }
                                          # parse the @command_array for "name=value" pairs
        begin
          # get the check the next value in the @command_array, continue only if
          # it's a name/value pair in the format 'name=value'
          name_val = @command_array[0]
          # if we've reached the end of the @command_array, break out of the loop
          break unless name_val
          # if it's not in the format 'name=value' then break out of the loop
          match = /([^=]+)=(.*)/.match(name_val)
          break unless match
          # since we've gotten this far, go ahead and shift the first value off
          # of the @command_array (ensuring that the @last_arg and @prev_args
          # variables are up to date as we do so)
          @last_arg = @command_array.shift
          @prev_args.push(@last_arg)
          # break apart the match array into the name and value parts
          name  = match[1]
          value = match[2]
          # if a list of expected names was passed into the function, then test
          # to see if this name is one of the expected names.  If it is in the list
          # of expected names, continue, otherwise thrown an error.  If no expected_names
          # list was passed in or if the value that was passed in has a zero length,
          # then any name will be accepted (and any corresponding name/value pair will
          # be returned)
          idx   = (expected_names && expected_names.size > 0 ? expected_names.index(name) : -1)
          raise ProjectRazor::Error::Slice::SliceCommandParsingFailed,
                "unrecognized field with name #{name}; valid values are #{expected_names.inspect}" unless idx
          # and add this name/value pair to the return_vals Hash map
          return_vals[name] = value
        end while @command_array.size > 0 # continue as long as there are more arguments to parse
        return return_vals
      end

      # returns the next argument from the @command_array (ensuring that the @last_arg and @prev_args
      # instance variables are kept consistent as it does so)
      def get_next_arg
        return_val = @command_array.shift
        @last_arg  = return_val
        @prev_args.push(return_val)
        return_val
      end

      def print_object_array(object_array, title = nil, options = { })
        # This is for backwards compatibility
        title = options[:title] unless title
        if @web_command
          if @uri_root
            object_array = object_array.collect do |object|

              if object.respond_to?("is_template") && object.is_template
                object.to_hash
              else
                obj_web = object.to_hash
                obj_web = Hash[obj_web.reject { |k, v| !%w(@uuid @classname, @noun).include?(k) }] unless object_array.count == 1

                add_uri_to_object_hash(obj_web)
                iterate_obj(obj_web)
                obj_web
              end
            end
          else
            object_array = object_array.collect { |object| object.to_hash }
          end

          slice_success(object_array, options)
        else
          puts title if title
          unless object_array.count > 0
            puts "< none >".red
          end
          if @verbose
            object_array.each do |obj|
              obj.instance_variables.each do |iv|
                unless iv.to_s.start_with?("@_")
                  key = iv.to_s.sub("@", "")
                  print "#{key}: "
                  print "#{obj.instance_variable_get(iv)}  ".green
                end
              end
              print "\n"
            end
          else
            print_array  = []
            header       = []
            line_colors  = []
            header_color = :white

            if (object_array.count == 1 || options[:style] == :item) && options[:style] != :table
              object_array.each do
              |object|
                puts print_single_item(object)
              end
            else
              object_array.each do |obj|
                print_array << obj.print_items
                header = obj.print_header
                line_colors << obj.line_color
                header_color = obj.header_color
              end
              # If we have more than one item we use table view, otherwise use item view
              print_array.unshift header if header != []
              puts print_table(print_array, line_colors, header_color)
            end
          end
        end
      end

      def iterate_obj(obj_hash)
        obj_hash.each do |k, v|
          if obj_hash[k].class == Array
            obj_hash[k].each do |item|
              if item.class == Hash
                add_uri_to_object_hash(item)
              end
            end
          end
        end
        obj_hash
      end

      def add_uri_to_object_hash(object_hash)
        noun = object_hash["@noun"]
        object_hash["@uri"] = "#@uri_root#{noun}/#{object_hash["@uuid"]}" if noun
        object_hash
      end

      def print_single_item(obj)
        print_array  = []
        header       = []
        line_color   = []
        print_output = ""
        header_color = :white

        if obj.respond_to?(:print_item) && obj.respond_to?(:print_item_header)
          print_array = obj.print_item
          header      = obj.print_item_header
        else
          print_array = obj.print_items
          header      = obj.print_header
        end
        line_color   = obj.line_color
        header_color = obj.header_color
        print_array.each_with_index do |val, index|
          if header_color
            print_output << " " + "#{header[index]}".send(header_color)
          else
            print_output << " " + "#{header[index]}"
          end
          print_output << " => "
          if line_color
            print_output << " " + "#{val}".send(line_color) + "\n"
          else
            print_output << " " + "#{val}" + "\n"
          end

        end
        print_output + "\n"
      end

      def print_table(print_array, line_colors, header_color)
        table = ""
        print_array.each_with_index do |line, li|
          line_string = ""
          line.each_with_index do |col, ci|
            max_col = print_array.collect { |x| x[ci].length }.max
            if li == 0
              if header_color
                line_string << "#{col.center(max_col)}  ".send(header_color)
              else
                line_string << "#{col.center(max_col)}  "
              end
            else
              if line_colors[li-1]
                line_string << "#{col.ljust(max_col)}  ".send(line_colors[li-1])
              else
                line_string << "#{col.ljust(max_col)}  "
              end
            end
          end
          table << line_string + "\n"
        end
        table
      end
    end
  end
end

