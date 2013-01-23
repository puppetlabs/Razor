test_name "Install Razor using Puppet"

case ENV['INSTALL_MODE']
when nil, '', 'git'      then
  source = 'git'
  repo   = ''
when 'internal-packages' then
  source = 'package'
  # This is going to have to change to respect the platform, eventually.
  repo   = '
apt::key { "internal-packages":
  key        => "27D8D6F1",
  key_source => "http://neptune.puppetlabs.lan/dev/razor/deb/pubkey.gpg",
  before     => Apt::Source["internal-packages"]
}

apt::source { "internal-packages":
  location    => "http://neptune.puppetlabs.lan/dev/razor/deb",
  release     => ${lsbdistcodename},
  repos       => "main",
  include_src => false,
  before      => Class[razor]
}
'
else
  raise "***** UNKNOWN INSTALL MODE [#{ENV['INSTALL_MODE'].inspect}] *****"
end


step "install razor modules"
# Find the package, and ensure we only have one!
require 'pathname'
if (modules = Pathname.glob("#{ENV['WORKSPACE']}/pkg/puppetlabs-razor-*.tar.gz")).size == 1
  pkg = modules[0].basename
  puts "we found #{pkg} to install"
else
  puts "we found NOTHING to install!"
  fail_test "unable to proceed, multiple modules found: #{modules.join(", ")}"
end

on hosts('razor-server'), "rm -f /tmp/puppetlabs-razor-*.tar.gz"
scp_to(hosts('razor-server'), "#{ENV['WORKSPACE']}/pkg/#{pkg}", '/tmp')
on hosts('razor-server'), "puppet module install --force /tmp/#{pkg}"

module_list  = "puppet module list --color=false 2>&1"
missing_deps = "#{module_list} | sed -ne '/Missing dependency/ s/^.*'\\''\\(.*\\)'\\''.*$/\\1/ p'"
next_missing = "$(#{missing_deps} | head -n1)"
on hosts('razor-server'), "module=\"#{next_missing}\"
while test -n \"${module}\"; do
    echo \"installing ${module}\"
    puppet module install --color=false \"${module}\"
    module=\"#{next_missing}\"
done"

step "configure razor, installing from #{source}"
on hosts('razor-server'), puppet_apply("--verbose"), :stdin => %Q'
#{repo}

class { sudo:
    config_file_replace => false,
}

class { razor:
  source    => #{source},
  username  => razor,
  mk_source => "https://github.com/downloads/puppetlabs/Razor-Microkernel/rz_mk_prod-image.0.9.0.4.iso",
}
'

step "validate razor installation"
on hosts('razor-server'), "/opt/razor/bin/razor_daemon.rb status" do
  assert_match(/razor_daemon: running/, stdout)
end

step "install gems to run the test suite"
on hosts('razor-server'), puppet_apply("--verbose"), :stdin => %q'
  package { [rake, rspec, mocha, net-ssh]: ensure => installed, provider => gem }
  package { curl: ensure => installed }
'

# check if we already have the spec files on the machine
step "copy the spec tests from git to the test host"
scp_to(hosts('razor-server'), "#{ENV['WORKSPACE']}/spec", '/opt/razor')
