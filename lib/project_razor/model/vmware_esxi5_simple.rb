# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved


# TODO - timing between state changes
# TODO - timeout values for a state

# Root ProjectRazor namespace
# @author Nicholas Weaver
module ProjectRazor
  module Model
    # Root Model object
    # @author Nicholas Weaver
    # @abstract
    class VMwareESXi5Simple < ProjectRazor::Model::Base

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
        @model_type = :vmware_hypervisor
        @name = "vmware_esxi5_simple"
        @description = "VMware ESXi 5 Simple Deployment"

        # Metadata vars
        esx_license = nil

        # State / must have a starting state
        @current_state = :init

        # Image UUID
        @image_uuid = true

        # Image prefix we can attach
        @image_prefix = "esxi"



        from_hash(hash) unless hash == nil
      end

      def req_metadata_hash
        {
            "@esx_license" => {:default => "",
                               :example => "AAAAA-BBBBB-CCCCC-DDDDD-EEEEE",
                               :validation => '^[A-Z\d]{5}-[A-Z\d]{5}-[A-Z\d]{5}-[A-Z\d]{5}-[A-Z\d]{5}$',
                               :required => true,
                               :description => "ESX License Key"}
        }
      end

      def callback
        {"boot_cfg" => :boot_cfg,
         "kickstart" => :kickstart,
         "postinstall" => :postinstall}
      end


      # Defines our FSM for this model
      #  For state => {action => state, ..}
      def fsm
        {
            :init => {:mk_call => :init,
                      :boot_call => :init,
                      :kickstart_start => :preinstall,
                      :kickstart_file => :init,
                      :kickstart_end => :postinstall,
                      :timeout => :timeout_error,
                      :error => :error_catch,
                      :else => :init},
            :preinstall => {:mk_call => :preinstall,
                            :boot_call => :preinstall,
                            :kickstart_start => :preinstall,
                            :kickstart_file => :init,
                            :kickstart_end => :postinstall,
                            :kickstart_timeout => :timeout_error,
                            :error => :error_catch,
                            :else => :preinstall},
            :postinstall => {:mk_call => :postinstall,
                            :boot_call => :postinstall,
                            :postinstall_end => :hypervisor_complete,
                            :kickstart_file => :postinstall,
                            :kickstart_end => :postinstall,
                            :kickstart_timeout => :postinstall,
                            :error => :error_catch,
                            :else => :preinstall},
            :hypervisor_complete => {:mk_call => :hypervisor_complete,
                                     :boot_call => :hypervisor_complete,
                                     :else => :hypervisor_complete,
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
          when :init, :preinstall, :postinstall, :hypervisor_complete
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
          when :postinstall, :hypervisor_complete
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
        ip << "kernel --name mboot.c32 #{image_svc_uri}/#{@image_uuid}/mboot.c32\n"
        ip << "imgargs mboot.c32 -c #{api_svc_uri}/policy/callback/#{policy_uuid}/boot_cfg\n"
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



      def boot_cfg(args_array, node, policy_uuid)
        @image = $data.fetch_object_by_uuid(:images, @image_uuid)
        @image.boot_cfg.gsub("/", "#{image_svc_uri}/#{@image_uuid}/").gsub("runweasel","ks=#{api_svc_uri}/policy/callback/#{policy_uuid}/kickstart/file")
      end

      def kickstart(args_array, node, policy_uuid)
        @node_bound = node
        @arg = args_array.shift
        case @arg
          when  "start"
            fsm_action(:kickstart_start, :kickstart)
            return "ok"
          when "end"
            fsm_action(:kickstart_end, :kickstart)
            return "ok"
          when "file"
            fsm_action(:kickstart_file, :kickstart)
            return kickstart_file(policy_uuid)
          else
            return "error"
        end
      end

      def postinstall(args_array, node, policy_uuid)
        @node_bound = node
        @arg = args_array.shift
        case @arg
          when  "end"
            fsm_action(:postinstall_end, :postinstall)
            return "ok"
          else
            return "error"
        end
      end

      def kickstart_file(policy_uuid)
        ks = ""
        ks << "accepteula\n"

        ks << "install --firstdisk --overwritevmfs\n"
        ks << "rootpw vmware123\n"
        #ks << "network --bootproto=dhcp --device=vmnic0 --addvmportgroup=0\n"
        ks << "reboot\n"
        ks << "\n"
        ks << "%include /tmp/networkconfig\n"
        ks << "\n"
        ks << "%pre --interpreter=busybox\n"
        ks << "\n"
        #ks << "wget #{api_svc_uri}/policy/callback/#{policy_uuid}/kickstart/start\n"
        #ks << "# extract network info from bootup\n"
        #ks << "VMK_INT='vmk0'\n"
        #ks << "VMK_LINE=$(localcli network ip interface ipv4 get | grep '${VMK_INT}')\n"
        #ks << "IPADDR=$(echo '${VMK_LINE}' | awk '{print $2}')\n"
        #ks << "NETMASK=$(echo '${VMK_LINE}' | awk '{print $3}')\n"
        #ks << "GATEWAY=$(esxcfg-route | awk '{print $5}')\n"
        #ks << "DNS='172.30.0.100,172.30.0.200'\n"
        #ks << "HOSTNAME=$(nslookup '${IPADDR}' | grep Address | awk '{print $4}')\n"
        ks << "\n"
        ks << "echo 'network --bootproto=static --addvmportgroup=false --device=vmnic0 --ip=192.168.99.110 --netmask=255.255.255.0 --gateway=192.168.99.10 --nameserver=192.168.99.10 --hostname=esx01.razorlab.local' > /tmp/networkconfig\n"
        ks << "\n"
        ks << "wget #{api_svc_uri}/policy/callback/#{policy_uuid}/kickstart/end\n"
        ks << "%firstboot --interpreter=busybox\n"
        ks << "\n"
        ks << "wget #{api_svc_uri}/policy/callback/#{policy_uuid}/postinstall/end\n"
        ks << "# enable HV (Hardware Virtualization to run nested 64bit Guests + Hyper-V VM)\n"
        ks << "grep -i 'vhv.allow' /etc/vmware/config || echo 'vhv.allow = 'TRUE'' >> /etc/vmware/config\n"
        ks << "vim-cmd hostsvc/enable_ssh\n"
        ks << "vim-cmd hostsvc/start_ssh\n"
        ks << "\n"
        ks << "# enable & start ESXi Shell (TSM)\n"
        ks << "vim-cmd hostsvc/enable_esx_shell\n"
        ks << "vim-cmd hostsvc/start_esx_shell\n"
        ks << "\n"
        ks << "esxcli system settings advanced set -o /UserVars/SuppressShellWarning -i 1\n"
        ks << "\n"
        ks << "\n"
        ks << "# rename local datastore to something more meaningful\n"
        ks << "vim-cmd hostsvc/datastore/rename datastore1 '$(hostname -s)-local-storage-1'\n"
        ks << "\n"
        ks << "# assign license\n"
        ks << "vim-cmd vimsvc/license --set #{@esx_license}\n"
        ks << "\n"
        ks << "\n"
        ks << "# change the individual syslog rotation count\n"
        ks << "esxcli system syslog config logger set --id=hostd --rotate=20 --size=2048\n"
        ks << "esxcli system syslog config logger set --id=vmkernel --rotate=20 --size=2048\n"
        ks << "esxcli system syslog config logger set --id=fdm --rotate=20\n"
        ks << "esxcli system syslog config logger set --id=vpxa --rotate=20\n"
        ks << "\n"
        ks << "### NTP CONFIGURATIONS ###\n"
        ks << "cat > /etc/ntp.conf << __NTP_CONFIG__\n"
        ks << "restrict default kod nomodify notrap noquerynopeer\n"
        ks << "restrict 127.0.0.1\n"
        ks << "server 0.vmware.pool.ntp.org\n"
        ks << "server 1.vmware.pool.ntp.org\n"
        ks << "__NTP_CONFIG__\n"
        ks << "/sbin/chkconfig --level 345 ntpd on\n"
        ks << "\n"
        ks << "### FIREWALL CONFIGURATION ###\n"
        ks << "\n"
        ks << "# enable firewall\n"
        ks << "esxcli network firewall set --default-action false --enabled yes\n"
        ks << "\n"
        ks << "# services to enable by default\n"
        ks << "FIREWALL_SERVICES='syslog sshClient ntpClient updateManager httpClient netdump'\n"
        ks << "for SERVICE in ${FIREWALL_SERVICES}\n"
        ks << "do\n"
        ks << "esxcli network firewall ruleset set --ruleset-id ${SERVICE} --enabled yes\n"
        ks << "done\n"
        ks << "\n"
        ks << "# backup ESXi configuration to persist changes\n"
        ks << "/sbin/auto-backup.sh\n"
        ks << "\n"
        ks << "# enter maintenance mode\n"
        ks << "vim-cmd hostsvc/maintenance_mode_enter\n"
        ks << "\n"
        ks << "# copy %first boot script logs to persisted datastore\n"
        ks << "cp /var/log/hostd.log '/vmfs/volumes/$(hostname -s)-local-storage-1/firstboot-hostd.log'\n"
        ks << "cp /var/log/esxi_install.log '/vmfs/volumes/$(hostname -s)-local-storage-1/firstboot-esxi_install.log'\n"
        ks << "\n"
        ks << "# Needed for configuration changes that could not be performed in esxcli (thanks VMware)\n"
        ks << "reboot\n"
        ks << "\n"
      end









    end
  end
end
