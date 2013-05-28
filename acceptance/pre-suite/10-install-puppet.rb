test_name "Install Puppet from PuppetLabs repositories"

script = %q"#!/bin/bash
# This script is intended to be used with the install action
# of puppet-cloudpack

set -u
set -e

function fedora_repo() {
  cat >/etc/yum.repos.d/puppet.repo <<'EOFYUMREPO'
[puppetlabs]
name = Puppetlabs
baseurl = http://yum.puppetlabs.com/fedora/f$releasever/products/$basearch/
gpgcheck = 1
enabled = 1
gpgkey = http://yum.puppetlabs.com/RPM-GPG-KEY-puppetlabs

[puppetlabs-deps]
name = Puppetlabs Dependencies
baseurl = http://yum.puppetlabs.com/fedora/f$releasever/dependencies/$basearch/
gpgcheck = 1
enabled = 1
gpgkey = http://yum.puppetlabs.com/RPM-GPG-KEY-puppetlabs
EOFYUMREPO
}

function el_repo() {
  cat >/etc/yum.repos.d/puppet.repo <<'EOFYUMREPO'
[puppetlabs]
name = Puppetlabs
baseurl = http://yum.puppetlabs.com/el/$releasever/products/$basearch/
gpgcheck = 1
enabled = 1
gpgkey = http://yum.puppetlabs.com/RPM-GPG-KEY-puppetlabs

[puppetlabs-deps]
name = Puppetlabs Dependencies
baseurl = http://yum.puppetlabs.com/el/$releasever/dependencies/$basearch/
gpgcheck = 1
enabled = 1
gpgkey = http://yum.puppetlabs.com/RPM-GPG-KEY-puppetlabs
EOFYUMREPO
}

function rpm_install() {
  # Setup the yum Puppet repository
  rpm -q fedora-release && fedora_repo || el_repo

  # Install Puppet from yum.puppetlabs.com
  yum install -y puppet
}

function apt_install() {
  # Download and install the puppetlabs apt public
  apt-key adv --recv-key --keyserver pool.sks-keyservers.net 4BD6EC30 || \
    apt-key adv --recv-key --keyserver pgp.mit.edu 4BD6EC30 || \
      apt-key adv --recv-key --keyserver keyserver.pgp.com 4BD6EC30

  # We need to grab the distro and release in order to populate
  # the apt repo details. We are assuming that the lsb_release command
  # will be available as even puppet evens has it (lsb_base) package as
  # dependancy.

  # Since puppet requires lsb-release I believe this is ok to use for
  # the purpose of distro and release discovery.
  apt-get -q -y update
  apt-get -y install lsb-release
  distro=$(lsb_release -i | cut -f 2 | tr '[:upper:]' '[:lower:]')
  release=$(lsb_release -c | cut -f 2)

  # Setup the apt Puppet repository
  cat > /etc/apt/sources.list.d/puppetlabs.list <<EOFAPTREPO
deb http://apt.puppetlabs.com/ ${release} main dependencies
EOFAPTREPO
  apt-get -q -y update
  # Install Puppet from Debian repositories
  apt-get -y install puppet
}

function install_puppet() {
  case ${breed} in
    'redhat')
      rpm_install ;;
    'debian')
      apt_install ;;
  esac
}

if [ -f /etc/redhat-release ]; then
  export breed='redhat'
elif [ -f /etc/debian_version ]; then
  export breed='debian'
else
  echo 'This OS is not supported by Puppet Cloud Provisioner'
  exit 1
fi

install_puppet"

create_remote_file hosts('razor-server'), "/tmp/install-puppet.sh", script
on hosts('razor-server'), "/bin/bash /tmp/install-puppet.sh"
on hosts('razor-server'), "/etc/init.d/puppet stop" # just in case...
