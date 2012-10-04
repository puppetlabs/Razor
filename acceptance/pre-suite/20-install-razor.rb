test_name "Install Razor using Puppet"

step "install razor modules"
on hosts, "puppet module install puppetlabs-razor"

step "configure razor"
on hosts, puppet_apply("--verbose"), :stdin => %q'
class { sudo:
    config_file_replace => false,
}

class { razor:
  username  => razor,
  mk_source => "https://github.com/downloads/puppetlabs/Razor-Microkernel/rz_mk_prod-image.0.9.0.4.iso",
}
'

step "validate razor installation"
on hosts, "/opt/razor/bin/razor_daemon.rb status" do
  assert_match(/razor_daemon: running/, stdout)
end

step "install gems to run the test suite"
on hosts, puppet_apply("--verbose"), :stdin => %q'
  package { [rake, rspec, mocha, net-ssh]: ensure => installed, provider => gem }
'
