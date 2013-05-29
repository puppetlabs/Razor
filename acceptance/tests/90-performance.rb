require 'pathname'

test_name "Razor Server Performance Testing"

Razor = hosts('razor-server')

step "Flush the existing project_razor mongo database"
on Razor, "mongo project_razor --eval 'db.dropDatabase()'"

step "Restart the razor daemon"
on Razor, "/opt/razor/bin/razor_daemon.rb restart"

def add_image(args = {})
  what = args[:name] || args[:type]
  uuid = nil
  url  = args.delete(:url)
  iso  = "/tmp/#{what}.iso"
  args = args.map{|k, v| "--#{k} '#{v}'"}.join(' ')

  step "Fetch the #{what} ISO"
  on Razor, "curl -Lo #{iso} #{url}"

  step "Install the #{what} image"
  on Razor, "razor image add #{args} --path #{iso}" do
    match = /UUID => +([a-zA-Z0-9]+)$/.match(stdout) || []
    uuid  = match[1]
    if !uuid or uuid.length < 15
      fail_test("unable to match the #{what} UUID from Razor:\nmatch: #{match.inspect}\nuuid:  #{uuid.inspect}\nout:\n#{stdout}")
    end
  end

  step "Remove the ISO image"
  on Razor, "rm -f #{iso}"

  return uuid
end

step "Add OS images to Razor"
mk_url = if ENV['INSTALL_MODE'] == 'internal-packages' then
           "http://neptune.puppetlabs.lan/dev/razor/iso/#{ENV['isobuild'] || 'current'}/#{ENV['mkflavour'] || 'prod'}/razor-microkernel-latest.iso"
         else
           "https://downloads.puppetlabs.com/razor/builds/iso/#{ENV['mkflavour'] || 'prod'}/razor-microkernel-latest.iso"
         end

mk     = add_image(:type => 'mk', :url => mk_url)
esxi   = add_image(:type => 'esxi', :url => "http://int-resources.ops.puppetlabs.net/Software/VMware/VMware-VMvisor-Installer-5.0.0-469512.x86_64.iso")
ubuntu = add_image(:type => 'os', :name => 'ubuntu', :version => '1204', :url => "http://int-resources.ops.puppetlabs.net/ISO/Ubuntu/ubuntu-12.04-server-amd64.iso")

# The simulator doesn't have a CentOS / EL scenario yet, but we should add
# one fairly soon.  When you do:
#
# centos = add_image(:type => 'os', :name => 'centos', :version => '62', :url => "http://int-resources.ops.puppetlabs.net/ISO/CentOS/CentOS-6.2-x86_64-minimal.iso")


step "Upload the perftest tool source code"
source = (Pathname.new(__FILE__).dirname + "../perftest").cleanpath.to_s
on Razor, "rm -rf /tmp/perftest"
scp_to(Razor, source, "/tmp")

step "Install required packages to build"
on hosts('razor-server'), puppet_apply("--verbose"), :stdin => %q'
package { "build-essential":     ensure => installed }
package { "pkg-config":          ensure => installed }
package { "libglib2.0-dev":      ensure => installed }
package { "libcurl4-gnutls-dev": ensure => installed }
package { "liburiparser-dev":    ensure => installed }
package { "make":                ensure => installed }
'

step "Build perftest"
on Razor, "cd /tmp/perftest && make"

step "Ensure that Razor is running cleanly"
on Razor, "/opt/razor/bin/razor_daemon.rb stop"
on Razor, "/opt/razor/bin/razor_daemon.rb start"
on Razor, "service xinetd restart"

step "Running perftest suite"
on Razor, "cd /tmp/perftest && " +
  "./perftest --target=localhost " +
  "--esxi-uuid=#{esxi} --ubuntu-uuid=#{ubuntu} --mk-uuid=#{mk} " +
  "--load=10 --population=20000"

step "Fetch back performance results"
perf = Pathname('../perf')
perf.directory? and perf.rmtree

Razor.each do |host|
  dir = perf + host
  dir.mkpath

  on host, "ls /tmp/perftest/*.{csv,jtl}", :acceptable_exit_codes => 0..65535 do
    stdout.split("\n").each do |file|
      next if file.include? '/*.' # nothing matches
      scp_from(host, file, dir + Pathname(file).basename)
    end
  end
end
