require 'socket'
require 'logger'
require 'fcntl'
require 'project_razor'
require 'project_razor/utility'
require 'project_razor/logging'

# This class represents the ProjectRazor configuration. It is stored persistently in
# './conf/razor_server.conf' and editing by the user
module ProjectRazor
  module Config
    class Server
      include ProjectRazor::Utility
      include ProjectRazor::Logging
      extend  ProjectRazor::Logging

      attr_accessor :image_svc_host

      attr_accessor :persist_mode
      attr_accessor :persist_host
      attr_accessor :persist_port
      attr_accessor :persist_timeout

      attr_accessor :admin_port
      attr_accessor :api_port
      attr_accessor :image_svc_port
      attr_accessor :mk_tce_mirror_port

      attr_accessor :mk_checkin_interval
      attr_accessor :mk_checkin_skew
      attr_accessor :mk_uri
      attr_accessor :mk_fact_excl_pattern
      attr_accessor :mk_register_path # : /project_razor/api/node/register
      attr_accessor :mk_checkin_path # checkin: /project_razor/api/node/checkin

      # mk_log_level should be 'Logger::FATAL', 'Logger::ERROR', 'Logger::WARN',
      # 'Logger::INFO', or 'Logger::DEBUG' (default is 'Logger::ERROR')
      attr_accessor :mk_log_level
      attr_accessor :mk_tce_mirror_uri
      attr_accessor :mk_tce_install_list_uri
      attr_accessor :mk_kmod_install_list_uri
      attr_accessor :mk_gem_mirror_uri
      attr_accessor :mk_gemlist_uri

      attr_accessor :image_svc_path

      attr_accessor :register_timeout
      attr_accessor :force_mk_uuid

      attr_accessor :default_ipmi_power_state
      attr_accessor :default_ipmi_username
      attr_accessor :default_ipmi_password

      attr_accessor :daemon_min_cycle_time

      attr_accessor :node_expire_timeout

      attr_accessor :rz_mk_boot_debug_level
      attr_accessor :rz_mk_boot_kernel_args

      attr_reader   :noun

      # Return a fully configured instance of the configuration data.
      #
      # If a configuration file exists on disk, it is loaded and validated.
      # If it works, because of the awesome choice of using YAML with fully
      # tagged objects, we have an instance to use.
      #
      # If it doesn't, or doesn't validate, we create a new instance, try to
      # save it to disk (without the TOCTOU race from the original), and use
      # that instead.
      #
      # @todo danielp 2013-03-13: this still doesn't address the race where a
      # *different* configuration is written to the default - in that case we
      # would totally just use the defaults rather than what was written.
      # If the original authors didn't care, though, I doubt that I should
      # care more deeply, rather than just delaying it until I replace the
      # model entirely.
      def self.instance
        unless @_instance
          logger.debug "Trying to loading config from (#{$config_server_path}"
          config = begin
                     YAML.load_file($config_server_path)
                   rescue StandardError, SyntaxError # thanks, Psych, for the later
                     nil
                   end

          # OK, the first round of validation that this is a good config; this
          # also handles upgrading the schema stored in the YAML file, if needed.
          if config.is_a? ProjectRazor::Config::Server
            config.defaults.each_pair {|key, value| config[key] ||= value }
          else
            logger.warn "Configuration validation failed loading (#{$config_server_path})"
            logger.warn "Resetting (#{$config_server_path}) and using default config"
            config = nil
          end

          # If we got here without a config object we should perform a reset,
          # including rewriting the configuration file iff it does not exist.
          unless config
            config = ProjectRazor::Config::Server.new

            # @todo danielp 2013-03-13: ...the rewrite.  This is probably a
            # terrible idea, even without the original TOCTOU race on
            # the file.
            config.save_as_yaml($config_server_path)
          end

          # ...but if we got here without error, we have our instance.
          @_instance = config
        end

        return @_instance
      end

      # Reset the singleton to the default state, primarily used for testing.
      # @api private
      def self._reset_instance
        @_instance = nil
      end

      def initialize
        defaults.each_pair {|name, value| self[name] = value }
        @noun = "config"
      end
      private "initialize"

      # Obtain our defaults
      def defaults
        defaults = {
          'image_svc_host'           => get_an_ip,
          'persist_mode'             => :mongo,
          'persist_host'             => "127.0.0.1",
          'persist_port'             => 27017,
          'persist_timeout'          => 10,

          'admin_port'               => 8025,
          'api_port'                 => 8026,
          'image_svc_port'           => 8027,
          'mk_tce_mirror_port'       => 2157,

          'mk_checkin_interval'      => 60,
          'mk_checkin_skew'          => 5,
          'mk_register_path'         => "/razor/api/node/register",
          'mk_checkin_path'          => "/razor/api/node/checkin",
          'mk_fact_excl_pattern'     => [
            "(^facter.*$)", "(^id$)", "(^kernel.*$)", "(^memoryfree$)",
            "(^operating.*$)", "(^osfamily$)", "(^path$)", "(^ps$)",
            "(^ruby.*$)", "(^selinux$)", "(^ssh.*$)", "(^swap.*$)",
            "(^timezone$)", "(^uniqueid$)", "(^uptime.*$)","(.*json_str$)"
          ].join("|"),
          'mk_log_level'             => "Logger::ERROR",
          'mk_gem_mirror_uri'        => "http://localhost:2158/gem-mirror",
          'mk_gemlist_uri'           => "http://localhost:2158/gem-mirror/gems/gem.list",

          'image_svc_path'           => $img_svc_path,

          'register_timeout'         => 120,
          'force_mk_uuid'            => "",

          'default_ipmi_power_state' => 'off',
          'default_ipmi_username'    => 'ipmi_user',
          'default_ipmi_password'    => 'ipmi_password',

          'daemon_min_cycle_time'    => 30,

          # this is the default value for the amount of time (in seconds) that
          # is allowed to pass before a node is removed from the system.  If the
          # node has not checked in for this long, it'll be removed
          'node_expire_timeout'      => 300,

          # DEPRECATED: use rz_mk_boot_kernel_args instead!
          # used to set the Microkernel boot debug level; valid values are
          # either the empty string (the default), "debug", or "quiet"
          'rz_mk_boot_debug_level'   => "",

          # used to pass arguments to the Microkernel's linux kernel;
          # e.g. "console=ttyS0" or "razor.ip=1.2.3.4"
          'rz_mk_boot_kernel_args'   => ""
        }

        # A handful of calculated default values that depend on pre-existing
        # default values.
        defaults['mk_uri'] =
          "http://#{defaults['image_svc_host']}:#{defaults['api_port']}"

        defaults['mk_tce_mirror_uri'] =
          "http://localhost:#{@mk_tce_mirror_port}/tinycorelinux"
        defaults['mk_tce_install_list_uri'] =
          defaults['mk_tce_mirror_uri'] + "/tce-install-list"
        defaults['mk_kmod_install_list_uri'] =
          defaults['mk_tce_mirror_uri'] + "/kmod-install-list"

        return defaults
      end

      # The fixed header injected at the top of any configuration file we write.
      ConfigHeader = <<EOT
#
# This file is the main configuration for ProjectRazor
#
# -- this was system generated --
#
#
EOT

      # Save the current configuration instance as YAML to disk.
      #
      # This tries reasonably hard to be secure against TOCTOU
      # vulnerabilities, which is why we end up with the nasty sysopen calls.
      # Thanks, Ruby, that makes my week. --daniel 2013-03-13
      def save_as_yaml(filename)
        begin
          fd = IO.sysopen(filename, Fcntl::O_WRONLY|Fcntl::O_CREAT|Fcntl::O_EXCL, 0600)
          IO.open(fd, 'wb') {|fh| fh.puts ConfigHeader, YAML.dump(self) }
        rescue
          # As per the original code, we treat any sort of failure as an
          # indication that we should just not give a damn about failures.
          #
          # If the file already existed, we will get here with Errno::E_EXISTS
          # as our exception.  If we want to handle that differently, that is
          # the path right there.
          logger.error "Could not save config to (#{filename})"
        end

        return self
      end

      # a few convenience methods that let us treat this class like a Hash map
      # (to a certain extent); first a "setter" method that lets users set
      # key/value pairs using a syntax like "config['param_name'] = param_value"
      def []=(key, val)
        # "@noun" is a "read-only" key for this class (there is no setter)
        return if key == "noun"
        self.send("#{key}=", val)
      end

      # next a "getter" method that lets a user get the value for a key using
      # a syntax like "config['param_name']"
      def [](key)
        self.send(key)
      end

      # next, a method that returns a list of the "key" fields from this class
      def keys
        self.to_hash.keys.map { |k| k.sub("@","") }
      end

      # and, finally, a method that gives users the ability to check and see
      # if a given parameter name is included in the list of "key" fields for
      # this class
      def include?(key)
        keys = self.to_hash.keys.map { |k| k.sub("@","") }
        keys.include?(key)
      end

      # returns the current "client configuration" parameters as a Hash map
      def get_client_config_hash
        config_hash = self.to_hash
        client_config_hash = {}
        config_hash.each_pair do
        |k,v|
          if k.start_with?("@mk_")
            client_config_hash[k.sub("@","")] = v
          end
        end
        client_config_hash
      end

      # uses the  UDPSocket class to determine the list of IP addresses that are
      # valid for this server (used in the "get_an_ip" method, below, to pick an IP
      # address to use when constructing the Razor configuration file)
      def local_ip
        # Base on answer from http://stackoverflow.com/questions/42566/getting-the-hostname-or-ip-in-ruby-on-rails
        orig, Socket.do_not_reverse_lookup = Socket.do_not_reverse_lookup, true  # turn off reverse DNS resolution temporarily

        UDPSocket.open do |s|
          s.connect '4.2.2.1', 1 # as this is UDP, no connection will actually be made
          s.addr.select {|ip| ip =~ /[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/}.uniq
        end
      ensure
        Socket.do_not_reverse_lookup = orig
      end

      # This method is used to guess at an appropriate value to use as an IP address
      # for the Razor server when constructing the Razor configuration file.  It returns
      # a single IP address from the set of IP addresses that are detected by the "local_ip"
      # method (above).  If no IP addresses are returned by the "local_ip" method, then
      # this method returns a default value of 127.0.0.1 (a localhost IP address) instead.
      def get_an_ip
        str_address = local_ip.first
        # if no address found, return a localhost IP address as a default value
        return '127.0.0.1' unless str_address
        # if we're using a version of Ruby other than v1.8.x, force encoding to be UTF-8
        # (to avoid an issue with how these values are saved in the configuration
        # file as YAML that occurs after Ruby 1.8.x)
        return str_address.force_encoding("UTF-8") unless /^1\.8\.\d+/.match(RUBY_VERSION)
        # if we're using Ruby v1.8.x, just return the string
        str_address
      end

    end
  end
end
