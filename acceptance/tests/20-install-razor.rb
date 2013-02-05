source = case ENV['INSTALL_MODE']
         when nil, '', 'git'      then 'git'
         when 'internal-packages' then 'package'
         else
           raise "unknown install mode '#{ENV['INSTALL_MODE']}"
         end

test_name "Install razor (with #{source})"

step "install razor"
mk_url = if ENV['INSTALL_MODE'] == 'internal-packages' then
           "http://neptune.puppetlabs.lan/dev/razor/iso/#{ENV['ISO_VERSION']}/razor-microkernel-latest.iso"
         else
           "https://github.com/downloads/puppetlabs/Razor-Microkernel/rz_mk_prod-image.0.9.0.4.iso"
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
