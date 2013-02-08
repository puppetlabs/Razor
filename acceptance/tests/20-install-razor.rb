source = case ENV['INSTALL_MODE']
         when nil, '', 'git'      then 'git'
         when 'internal-packages' then 'package'
         else
           raise "unknown install mode '#{ENV['INSTALL_MODE']}"
         end

test_name "Install razor (with #{source})"

step "install razor"
mk_url = if ENV['INSTALL_MODE'] == 'internal-packages' then
           "http://neptune.puppetlabs.lan/dev/razor/iso/#{ENV['isobuild']}/#{ENV['mkflavour']}/razor-microkernel-latest.iso"
         else
           "https://downloads.puppetlabs.com/razor/builds/iso/${ENV['mkflavour'] || 'prod'}/razor-microkernel-latest.iso"
         end

on hosts('razor-server'), puppet_apply("--verbose"), :stdin => %Q'
class { sudo: config_file_replace => false }
class { razor: source => #{source}, username => razor, mk_source => "#{mk_url}" }
'

step "validate razor installation"
on hosts('razor-server'), "/opt/razor/bin/razor_daemon.rb status" do
  assert_match(/razor_daemon: running/, stdout)
end

step "copy the spec tests from git to the test host"
scp_to(hosts('razor-server'), "#{ENV['WORKSPACE']}/spec", '/opt/razor')
