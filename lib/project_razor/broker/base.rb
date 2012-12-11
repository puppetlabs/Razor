# Root namespace for ProjectRazor
module ProjectRazor
  module BrokerPlugin

    # Root namespace for Brokers defined in ProjectRazor for node hand off
    # @abstract
    class Base < ProjectRazor::Object
      attr_accessor :name
      attr_accessor :plugin
      attr_accessor :description
      attr_accessor :user_description
      attr_accessor :hidden
      attr_accessor :req_metadata_hash

      def initialize(hash)
        super()
        @hidden = true
        @plugin = :base
        @noun = "broker"
        @description = "Base broker plugin - not used"
        @_namespace = :broker
        from_hash(hash) if hash
      end

      def template
        @plugin
      end


      def agent_hand_off(options = {})

      end

      def proxy_hand_off(options = {})

      end

      # Method call for validating that a Broker instance successfully received the node
      def validate_broker_hand_off(options = {})
        # return false because the Base object does nothing
        # Child objects do not need to call super
        false
      end

      def print_header
        if @is_template
          return "Plugin", "Description"
        else
          return "Name", "Description", "Plugin", "UUID"
        end
      end

      def print_items
        if @is_template
          return @plugin.to_s, @description.to_s
        else
          return @name, @user_description, @plugin.to_s, @uuid
        end
      end

      def line_color
        :white_on_black
      end

      def header_color
        :red_on_black
      end

      def web_create_metadata(provided_metadata)
        missing_metadata = []
        rmd = req_metadata_hash
        rmd.each_key do
        |md|
          metadata = map_keys_to_symbols(rmd[md])
          provided_metadata = map_keys_to_symbols(provided_metadata)
          md = (!md.is_a?(Symbol) ? md.gsub(/^@/,'').to_sym : md)
          md_fld_name = '@' + md.to_s
          if provided_metadata[md]
            raise ProjectRazor::Error::Slice::InvalidModelMetadata, "Invalid Metadata [#{md.to_s}:'#{provided_metadata[md]}']" unless
                set_metadata_value(md_fld_name, provided_metadata[md], metadata[:validation])
          else
            if metadata[:default] != ""
              raise ProjectRazor::Error::Slice::MissingModelMetadata, "Missing metadata [#{md.to_s}]" unless
                  set_metadata_value(md_fld_name, metadata[:default], metadata[:validation])
            else
              raise ProjectRazor::Error::Slice::MissingModelMetadata, "Missing metadata [#{md.to_s}]" if metadata[:required]
            end
          end
        end
      end

      def cli_create_metadata
        puts "--- Building Broker (#{plugin}): #{name}\n".yellow
        req_metadata_hash.each_key { |key|
          metadata = map_keys_to_symbols(req_metadata_hash[key])
          key = key.to_sym if !key.is_a?(Symbol)
          flag = false
          until flag
            print "Please enter " + "#{metadata[:description]}".yellow.bold
            print " (example: " + "#{metadata[:example]}".yellow + ") \n"
            puts "default: " + "#{metadata[:default]}".yellow if metadata[:default] != ""
            puts metadata[:required] ? quit_option : skip_quit_option
            print " > "
            response = read_input(metadata[:multiline])
            case response
              when "SKIP"
                if metadata[:required]
                  puts "Cannot skip, value required".red
                else
                  flag = true
                end
              when "QUIT"
                return false
              when ""
                if metadata[:default] != ""
                  flag = set_metadata_value(key, metadata[:default], metadata[:validation])
                else
                  puts "No default value, must enter something".red
                end
              else
                flag = set_metadata_value(key, response, metadata[:validation])
                puts "Value (".red + "#{response}".yellow + ") is invalid".red unless flag
            end
          end
        }
        true
      end

      def read_input(multiline = false)
        if multiline
          response = ""
          while line = STDIN.gets
            if line =~ /^$/
              break
            else
              response += line
            end
          end
          response
        else
          STDIN.gets.strip
        end
      end

      def map_keys_to_symbols(hash)
        tmp = {}
        hash.each { |key, val|
          key = key.to_sym if !key.is_a?(Symbol)
          tmp[key] = val
        }
        tmp
      end

      def set_metadata_value(key, value, validation)
        regex = Regexp.new(validation)
        if regex =~ value
          self.instance_variable_set(key.to_sym, value)
          true
        else
          false
        end
      end

      def skip_quit_option
        "(" + "SKIP".white + " to skip, " + "QUIT".red + " to cancel)"
      end

      def quit_option
        "(" + "QUIT".red + " to cancel)"
      end
    end
  end
end
