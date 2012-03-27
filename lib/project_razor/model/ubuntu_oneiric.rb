# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved


# TODO - timing between state changes
# TODO - timeout values for a state
# TODO - Model sequence log (collection)

# Root ProjectRazor namespace
# @author Nicholas Weaver
module ProjectRazor
  module Model
    # Root Model object
    # @author Nicholas Weaver
    # @abstract
    class UbuntuOneiricMinimal < ProjectRazor::Model::Base

      # Assigned image
      attr_accessor :image_uuid

      # Metadata
      attr_accessor :hostname

      # Compatible Image Prefix
      attr_accessor :image_prefix


      def initialize(hash)
        super(hash)

        # Static config
        @hidden = false
        @model_type = :linux_deploy
        @name = "ubuntu_oneiric_min"
        @description = "Ubuntu Oneiric 11.10 Minimal"

        # Metadata vars
        @hostname = nil

        # State / must have a starting state
        @current_state = :init

        # Image UUID
        @image_uuid = true

        # Image prefix we can attach
        @image_prefix = "os"



        from_hash(hash) unless hash == nil
      end

      def req_metadata_hash
        {
            "@hostname" => {:default => "",
                            :example => "hostname.example.org",
                            :validation => '^[\w.]+$',
                            :required => true,
                            :description => "node hostname"}
        }
      end

      def callback
        {"preseed" => :preseed_call,
         "postinstall" => :postinstall}
      end

      def postinstall(args_array, node, policy_uuid)
        @node_bound = node

        @arg = args_array.shift

        case @arg
          when "inject"
            fsm_action(:postinstall_inject, :postinstall)
            return os_boot_script(policy_uuid)
          when "boot"
            fsm_action(:os_boot, :postinstall)
            return os_complete_script(node)
          else
            return
        end


      end


      def os_boot_script(policy_uuid)
        "#!/bin/bash
curl #{api_svc_uri}/policy/callback/#{policy_uuid}/postinstall/boot | sh
"
      end

      def os_complete_script(node)
"#!/bin/bash
echo Razor policy successfully applied > /tmp/razor_complete.log
echo Model #{@label} - #{@description} >> /tmp/razor_complete.log
echo Image UUID #{@image_uuid} >> /tmp/razor_complete.log
echo Node UUID: #{node.uuid} >> /tmp/razor_complete.log

hostname #{@hostname}
echo #{@hostname} >> /etc/hostname
sed -i '/razor_postinstall/d' /etc/rc.local
"
      end

      def preseed_call(args_array, node, policy_uuid)
        @node_bound = node

        @arg = args_array.shift

        case @arg

          when  "start"
            fsm_action(:preseed_start, :preseed)
            return "ok"

          when "end"
            fsm_action(:preseed_end, :preseed)
            return "ok"
          when "file"
            fsm_action(:preseed_file, :preseed)
            return generate_preseed(policy_uuid)

          else
            return "error"
        end

      end




      def nl(s)
        s + "\n"
      end


      # Defines our FSM for this model
      #  For state => {action => state, ..}
      def fsm
        {
            :init => {:mk_call => :init,
                      :boot_call => :init,
                      :preseed_start => :preinstall,
                      :preseed_file => :init,
                      :preseed_end => :postinstall,
                      :timeout => :timeout_error,
                      :error => :error_catch,
                      :else => :init},
            :preinstall => {:mk_call => :preinstall,
                            :boot_call => :preinstall,
                            :preseed_start => :preinstall,
                            :preseed_file => :init,
                            :preseed_end => :postinstall,
                            :preseed_timeout => :timeout_error,
                            :error => :error_catch,
                            :else => :preinstall},
            :postinstall => {:mk_call => :postinstall,
                             :boot_call => :postinstall,
                             :preseed_end => :postinstall,
                             :postinstall_inject => :postinstall,
                             :os_boot => :os_complete,
                             :post_error => :error_catch,
                             :post_timeout => :timeout_error,
                             :error => :error_catch,
                             :else => :error_catch},
            :os_complete => {:mk_call => :os_complete,
                             :boot_call => :os_complete,
                             :else => :os_complete,
                             :reset => :init},
            :timeout_error => {:mk_call => :timeout_error,
                               :boot_call => :timeout_error,
                               :else => :timeout_error,
                               :reset => :init},
            :error_catch => {:mk_call => :error_catch,
                             :boot_call => :error_catch,
                             :else => :error_catch,
                             :reset => :init},
        }
      end


      def mk_call(node, policy_uuid)
        @node_bound = node


        case @current_state

          # We need to reboot
          when :init, :preinstall, :postinstall, :os_validate, :os_complete
            ret = [:reboot, {}]
          when :timeout_error, :error_catch
            ret = [:acknowledge, {}]
          else
            ret = [:acknowledge, {}]
        end

        fsm_action(:mk_call, :mk_call)
        ret
      end

      def boot_call(node, policy_uuid)
        @node_bound = node

        case @current_state

          when :init, :preinstall
            ret = start_install(node, policy_uuid)
          when :postinstall, :os_complete
            ret = local_boot(node)
          when :timeout_error, :error_catch
            engine = ProjectRazor::Engine.instance
            ret = engine.default_mk_boot(node.uuid)
          else
            engine = ProjectRazor::Engine.instance
            ret = engine.default_mk_boot(node.uuid)
        end

        fsm_action(:boot_call, :boot_call)
        ret
      end

      def start_install(node, policy_uuid)
        ip = "#!ipxe\n"
        ip << "echo Reached #{@label} model boot_call\n"
        ip << "echo Our image UUID is: #{@image_uuid}\n"
        ip << "echo Our state is: #{@current_state}\n"
        ip << "echo Our node UUID: #{node.uuid}\n"
        ip << "\n"
        ip << "echo We will be running an install now\n"
        ip << "sleep 3\n"
        ip << "\n"
        ip << "kernel #{image_svc_uri}/#{@image_uuid}/#{kernel_path} #{kernel_args(policy_uuid)}  || goto error\n"
        ip << "initrd #{image_svc_uri}/#{@image_uuid}/#{initrd_path} || goto error\n"
        ip << "boot\n"
        ip
      end

      def local_boot(node)
        ip = "#!ipxe\n"
        ip << "echo Reached #{@label} model boot_call\n"
        ip << "echo Our image UUID is: #{@image_uuid}\n"
        ip << "echo Our state is: #{@current_state}\n"
        ip << "echo Our node UUID: #{node.uuid}\n"
        ip << "\n"
        ip << "echo Continuing local boot\n"
        ip << "sleep 3\n"
        ip << "\n"
        ip << "sanboot --no-describe --drive 0x80\n"
        ip
      end


      def kernel_args(policy_uuid)
        ka = ""
        ka << "preseed/url=#{api_svc_uri}/policy/callback/#{policy_uuid}/preseed/file "
        ka << "debian-installer/locale=en_US "
        ka << "netcfg/choose_interface=auto "
        ka << "priority=critical "
        ka
      end

      def kernel_path
        "install/netboot/ubuntu-installer/amd64/linux"
      end

      def initrd_path
        "install/netboot/ubuntu-installer/amd64/initrd.gz"
      end

      def config
        $data.config
      end

      def image_svc_uri
        "http://#{config.image_svc_host}:#{config.image_svc_port}/razor/image/os"
      end

      def api_svc_uri
        "http://#{config.image_svc_host}:#{config.api_port}/razor/api"
      end



      def generate_preseed(policy_uuid)
        "d-i console-setup/ask_detect boolean false

d-i keyboard-configuration/layoutcode string us

d-i netcfg/choose_interface select auto


d-i netcfg/get_hostname string #{@hostname}
d-i netcfg/get_domain string razorlab.local


d-i mirror/protocol string http
d-i mirror/country string manual
d-i mirror/http/hostname string #{config.image_svc_host}:#{config.image_svc_port}
d-i mirror/http/directory string /razor/image/os/#{@image_uuid}
d-i mirror/http/proxy string


d-i clock-setup/utc boolean true

d-i time/zone string US/Central


d-i clock-setup/ntp boolean true



d-i partman-auto/disk string /dev/sda

d-i partman-auto/method string lvm
d-i partman-lvm/device_remove_lvm boolean true

d-i partman-md/device_remove_md boolean true

d-i partman-lvm/confirm boolean true


d-i partman-auto-lvm/guided_size string max

d-i partman-auto/choose_recipe select atomic


d-i partman/default_filesystem string ext4


d-i partman-partitioning/confirm_write_new_label boolean true
d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true


d-i partman-md/confirm boolean true
d-i partman-partitioning/confirm_write_new_label boolean true
d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true


d-i passwd/root-login boolean true
d-i passwd/make-user boolean true


d-i passwd/root-password password test123
d-i passwd/root-password-again password test123



d-i passwd/user-fullname string User
d-i passwd/username string user

d-i passwd/user-password password insecure
d-i passwd/user-password-again password insecure

d-i user-setup/allow-password-weak boolean true



d-i apt-setup/restricted boolean true
d-i apt-setup/universe boolean true
d-i apt-setup/backports boolean true



d-i pkgsel/include string openssh-server build-essential curl


d-i grub-installer/only_debian boolean true

d-i grub-installer/with_other_os boolean true

d-i finish-install/reboot_in_progress note


#Our callbacks
d-i preseed/early_command string wget #{api_svc_uri}/policy/callback/#{policy_uuid}/preseed/start

d-i preseed/late_command string \\
    wget #{api_svc_uri}/policy/callback/#{policy_uuid}/preseed/end; \\
    wget #{api_svc_uri}/policy/callback/#{policy_uuid}/postinstall/inject -O /target/usr/local/bin/razor_postinstall.sh; \\
    sed -i '/exit 0/d' /target/etc/rc.local; \\
    echo bash /usr/local/bin/razor_postinstall.sh >> /target/etc/rc.local; \\
    echo exit 0 >> /target/etc/rc.local; \\
    chmod +x /target/usr/local/bin/razor_postinstall.sh
"
      end
    end
  end
end
