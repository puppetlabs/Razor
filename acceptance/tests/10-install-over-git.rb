test_name "Install packages over git"
if ENV['INSTALL_MODE'] == 'git' then
  skip_test "We don't test `install over git` unless we are testing packages"
end

razor = hosts('razor-server')

step "Ensure that the package is not installed"
on razor, puppet_resource('package', 'puppet-razor', 'ensure=absent') do
  if stdout =~ /Error/i or stderr =~ /Error/i then
    fail_test("I guess an error happened during the ensure=absent run, maybe?")
  end
end

step "Ensure that the Razor directory is not present"
on razor, "test -e /opt/razor && rm -rf /opt/razor || :"

teardown do
  step "Remove that stub directory"
  # Right now this always returns zero, but tomorrow we might need to fix it
  # to respect a decent exit code. --daniel 2013-01-28
  on razor, puppet_resource('package', 'puppet-razor', 'ensure=absent')
  on razor, "test -e /opt/razor && rm -rf /opt/razor || :"
end

# I wish this could be less intrusive, but there really isn't any other
# option; while installation is still so full of random "install from
# upstream" bits, we have to run the full module to get a sane install.
step "install razor from git"
mk_url = if ENV['INSTALL_MODE'] == 'internal-packages' then
           "http://neptune.puppetlabs.lan/dev/razor/iso/#{ENV['ISO_VERSION']}/razor-microkernel-latest.iso"
         else
           "https://github.com/downloads/puppetlabs/Razor-Microkernel/rz_mk_prod-image.0.9.0.4.iso"
         end

on hosts('razor-server'), puppet_apply("--verbose"), :stdin => %Q'
class { sudo: config_file_replace => false }
class { razor: source => git, username => razor, mk_source => "#{mk_url}" }
'

step "Ensure we fail to install the package!"
# This doesn't check for exit codes, only error messages, because
# in 3.0.2 ralsh kinda sucks: http://projects.puppetlabs.com/issues/18937
# --daniel 2013-01-28
on razor, puppet_resource('package', 'puppet-razor', 'ensure=latest') do
  unless (stdout + stderr) =~ /ensure => '(absent|purged)'/ then
    fail_test("I guess maybe we installed something when we shouldn't have, maybe?")
  end
end
