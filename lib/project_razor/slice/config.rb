require "json"
require "yaml"

# Root ProjectRazor namespace
module ProjectRazor
  class Slice
    # ProjectRazor Slice Boot
    # Used for all boot logic by node
    class Config < ProjectRazor::Slice
      include(ProjectRazor::Logging)
      # Initializes ProjectRazor::Slice::Model including #slice_commands, #slice_commands_help, & #slice_name
      # @param [Array] args
      def initialize(args)
        super(args)
        @hidden = true
        # Here we create a hash of the command string to the method it corresponds to for routing.
        @slice_commands = {
          :read    => "read_config",
          :dbcheck => "db_check",
          :ipxe    => "generate_ipxe_script",
          :default => :read,
          :else    => :read
        }
        @slice_name = "Config"
        @engine = ProjectRazor::Engine.instance
      end

      def db_check
        raise ProjectRazor::Error::Slice::MethodNotAllowed, "This method cannot be invoked via REST" if @web_command
        puts get_data.persist_ctrl.is_connected?
      end

      def read_config
        setup_data
        if @web_command # is this a web command
          print ProjectRazor.config.to_hash.to_json
        else
          puts "ProjectRazor Config:"
          ProjectRazor.config.to_hash.each do
          |key,val|
            print "\t#{key.sub("@","")}: ".white
            print "#{val} \n".green
          end
        end
      end

      def generate_ipxe_script
        setup_data

        @ipxe_options = {}
        @ipxe_options[:style] = :new
        @ipxe_options[:uri] =  ProjectRazor.config.mk_uri
        @ipxe_options[:timeout_sleep] = 15
        @ipxe_options[:nic_max] = 7

        ipxe_script = File.join(File.dirname(__FILE__), "config/razor.ipxe.erb")
        puts ERB.new(File.read(ipxe_script)).result(binding)
      end

    end
  end
end
