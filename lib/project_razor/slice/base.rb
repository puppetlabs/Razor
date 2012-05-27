require "json"
require "colored"

# TODO - change help printing to multi-line with header and description
# TODO - add ability to hide commands from CLI help

# Root ProjectRazor namespace
module ProjectRazor
  module Slice
    # Abstract parent class for all ProjectRazor Modules
    # @abstract
    class Base < ProjectRazor::Object
      include(ProjectRazor::SliceUtil::Common)
      include(ProjectRazor::Logging)

      # Bool for indicating whether this was driven from Node.js
      attr_accessor :command_array, :slice_name, :slice_commands, :web_command, :hidden
      attr_accessor :verbose
      attr_accessor :debug

      # Initializes the Slice Base
      # @param [Array] args
      def initialize(args)
        @command_array = args
        @command_help_text = nil
        @slice_commands = {}
        @web_command = false
        @last_arg = nil
        @prev_args = Stack.new
        @hidden = true
        @helper_message_objects = nil
        setup_data
        @uri_root = @data.config.mk_uri + "/razor/api/"
      end

      # Default call method for a slice
      # Used by {./bin/project_razor}
      # Parses the #command_array and determines the action based on #slice_commands for child object
      def slice_call
        begin
          # Switch command/arguments to lower case
          # @command_array.map! {|x| x.downcase}
          if @new_slice_style
            @command_hash = @slice_commands
            new_slice_call
            return
          end

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
            # If we haven't called a command we need to either call :else or return an error
            if !flag
              # Check if there is an else catch for the slice
              if @slice_commands[:else]
                logger.debug "Slice command called: Else"
                @command_array.unshift(@command) # Add the command back as it is a arg for :else now
                self.send(@slice_commands[:else])
              else
                raise ProjectRazor::Error::Slice::InvalidCommand, "Invalid Command [#{@command}]"
              end
            end
          end

        rescue => e
          if @debug
            raise e
          else
            slice_error(e)
          end
        end
      end


      def new_slice_call
        #puts "New Slice Call"
        #puts @command_array.inspect
        @command_hash = @slice_commands
        eval_command
      end

      def eval_command
        #puts "Evaluating slice command"

        unless @command_array.count > 0
          # No commands or arguments are left, we need to call the :default action
          if @slice_commands[:default]
            #puts "No command specified using calling (default)"
            eval_action(@command_hash[:default])
            return
          else
            #puts "No (default) action defined"
            raise ProjectRazor::Error::Slice::Generic, "No Default Action"
            return
          end
        end

        # each key in the command hash - eval in against command_array
        # If command_array is empty we call default - if it does not exist we call :else
        # If nothing matches then we call the :else - if :else does not exist we throw error
        if @command_array.first == "help"
          list_help
          return
        end

        @command_hash.each do
        |k,v|
          case k.class.to_s
            when "Symbol"
              #puts "Comparing #{@command_array.first.to_s} to #{k.to_s}(Symbol)"
              if @command_array.first.to_s == k.to_s
                #puts "**** Command matches - evaluating action"
                #puts "removing arg"
                @last_arg = @command_array.shift
                @prev_args.push(@last_arg)
                return eval_action(@command_hash[k])
              end
            when "String"
              #puts "Comparing #{@command_array.first.to_s} to #{k.to_s}(String)"
              if @command_array.first.to_s == k.to_s
                #puts "**** Command matches - evaluating action"
                #puts "removing arg"
                @last_arg = @command_array.shift
                @prev_args.push(@last_arg)
                return eval_action(@command_hash[k])
              end
            when "Regexp"
              #puts "Command is a regexp"
              if @command_array.first =~ k
                #puts "**** Command matches - evaluating action"
                #puts "removing arg"
                @last_arg = @command_array.shift
                @prev_args.push(@last_arg)
                return eval_action(@command_hash[k])
              end
            when "Array"
              #puts "Command is a array"
              if eval_command_array(k)
                #puts "removing arg"
                @last_arg =  @command_array.shift
                @prev_args.push(@last_arg)
                return eval_action(@command_hash[k])
              end
            else
              #puts "Raise error, invalid type"
          end
        end

        # We did not find a match, we call :else
        #puts "No match for #{@command_array.first}"
        if @command_hash[:else]
          #puts "No command specified using calling (else)"
          return eval_action(@command_hash[:else])
        else
          #puts "No (else) action defined"
          raise ProjectRazor::Error::Slice::InvalidCommand, "System Error: no else action for slice"
          return
        end
      end

      def eval_command_array(command_array)
        command_array.each do
        |command_item|
          case command_item.class.to_s
            when "String", nil
              #puts "Comparing #{@command_array.first.to_s} to #{command_item.to_s}(String)"
              return true if @command_array.first.to_s == command_item
            when "Regexp"
              #puts "Comparing #{@command_array.first} to #{command_item.to_s}(Regexp)"
              return true if @command_array.first =~ command_item
            else

          end
        end
        false
      end

      def eval_action(command_action)
        case command_action.class.to_s
          when "Symbol"
            #puts "Action is a Symbol"
            #puts "Calling command (#{command_action}) in command_hash"
            #puts "inserting arg"
            @command_array.unshift(command_action.to_s)
            #puts @command_array.inspect
            eval_command
          when "String"
            #puts "Action is a String"
            #puts "Calling method in slice (#{command_action})"
            self.send(command_action)
          when "Hash"
            #puts "Action is a Hash"
            #puts "Iterating on Hash"
            @command_hash = command_action
            eval_command
          else
            #puts "Unknown command, throwing error"
            #puts command_action.class.to_s
            raise "InvalidActionSlice"
        end
      end

      # Called when slice action is successful
      # Returns a json string representing a [Hash] with metadata and response
      # @param [Hash] response
      def slice_success(response, options = {})
        mk_response = options[:mk_response] ? options[:mk_response] : false
        type = options[:success_type] ? options[:success_type] : :generic

        # Slice Success types
        # Created, Updated, Removed, Retrieved. Generic

        return_hash = {}
        return_hash["resource"] = self.class.to_s
        return_hash["command"] = @command
        return_hash["result"] = success_types[type][:message]
        return_hash["http_err_code"] = success_types[type][:http_code]
        return_hash["errcode"] = 0
        return_hash["response"] = response
        setup_data
        return_hash["client_config"] = @data.config.get_client_config_hash if mk_response
        if @web_command
          puts JSON.dump(return_hash)
        else
          print "\n\n#{@slice_name.capitalize}"
          print " #{return_hash["command"]}\n"
          print " #{return_hash["response"]}\n"
        end
        logger.debug "(#{return_hash["resource"]}  #{return_hash["command"]}  #{return_hash["result"]})"
      end

      def success_types
        {
            :generic => {
                :http_code => 200,
                :message => "Ok"
            },
            :created => {
                :http_code => 201,
                :message => "Created"
            },
            :updated => {
                :http_code => 202,
                :message => "Updated"
            },
            :removed => {
                :http_code => 202,
                :message => "Removed"
            }
        }
      end

      # Called when a slice action triggers an error
      # Returns a json string representing a [Hash] with metadata including error code and message
      # @param [Hash] error
      def slice_error(error, options = {})
        mk_response = options[:mk_response] ? options[:mk_response] : false
        setup_data
        return_hash = {}
        log_level = :error
        if error.class.ancestors.include?(ProjectRazor::Error::Slice::Generic)
          return_hash["std_err_code"] = error.std_err
          return_hash["err_class"] = error.class.to_s
          return_hash["result"] = error.message
          return_hash["http_err_code"] = error.http_err_code
          log_level = error.log_severity
        else
          # We use old style if error is String
          return_hash["std_err_code"] = 1
          return_hash["result"] = error
          logger.error "Slice error: #{return_hash.inspect}"

        end

        @command = "null" if @command == nil
        return_hash["slice"] = self.class.to_s
        return_hash["command"] = @command
        return_hash["client_config"] = @data.config.get_client_config_hash if mk_response
        if @web_command
          puts JSON.dump(return_hash)
        else
          if @new_slice_style
            list_help(return_hash)
          else
            available_commands(return_hash)
          end
        end
        logger.send log_level, "Slice Error: #{return_hash["result"]}"
      end

      # Prints available commands to CLI for slice
      # @param [Hash] return_hash
      def available_commands(return_hash)
        print "\nAvailable commands for [#@slice_name]:\n"
        @slice_commands.each_key do
        |k|
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

      def list_help(return_hash = nil)
        if return_hash != nil
          print "[#{@slice_name.capitalize}] "
          print "[#{return_hash["command"]}] ".red
          print "<-#{return_hash["result"]}\n".yellow
        end
        @command_hash[:help] = "n/a" unless @command_hash[:help]
        if @command_help_text
          puts "\nCommand help:\n" +  @command_help_text
        else
          puts "\nCommand help:\n" +  @command_hash[:help]
        end
      end

      def load_slice_commands
        begin
          @slice_commands = YAML.load_file(slice_commands_file)
        rescue => e
          raise ProjectRazor::Error::Slice::SliceCommandParsingFailed, "Slice #{@slice_name} cannot parse command file"
        end
      end

      def save_slice_commands
        f = File.new(slice_commands_file,  "w+")
        f.write(YAML.dump(@slice_commands))
      end

      def slice_commands_file
        File.join(File.dirname(__FILE__), "#{@slice_name.downcase}/commands.yaml")
      end

      # Initializes [ProjectRazor::Data] in not already instantiated
      def setup_data
        @data = get_data unless @data.class == ProjectRazor::Data
      end

    end
  end
end
