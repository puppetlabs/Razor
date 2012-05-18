# Project Razor

## License

See LICENSE file.

## Introduction

Project Razor is a power control, provisioning, and management application designed
to deploy both bare-metal and virtual compute resources with tight integration to
DevOps-style tool sets.

This is a 0.x release the API is still in flux and may change. Make sure you read
the release notes before upgrading.

## Authors

[Nicholas Weaver](https://github.com/lynxbat)
[Tom McSweeney](https://github.com/tjmcs)

## Installation

Razor requires tftp and dhcp service. The razor client will contact the same
server providing tftp files, so both service must reside on the same server.

### Puppet Prereqs:

Puppet razor module will perform the installation of dependency on Debian Wheezy system:

https://github.com/puppetlabs/puppet-razor

Here's a list of dependency for razor module:

* [Node.js module](https://github.com/nanliu/puppet-nodejs)
* [Mongodb module](https://github.com/nanliu/puppet-mongodb)
* [tftp module](https://github.com/nanliu/puppet-tftp)

Puppet master, add razor class to target node:

    node razor_system {
      include razor
    }

Puppet apply, apply test manifests:

    puppet apply razor/tests/init.pp

### Manual Prereqs:

Install the following software requirement for your platform:

* Ruby >= 1.9.3
* Assorted gems - see (Gemfile)
* Node.js >= 0.6.10
[Node.js install with package manager](https://github.com/joyent/node/wiki/Installing-Node.js-via-package-manager)
* Node.js Express package
[Node Package Manager(NPM)](http://npmjs.org/)
[Express install via NPM](http://expressjs.com/guide.html)
* Mongo database >= 2.0.X+

### Razor:

Configure dhcpd configuration to retrieve pexlinux.0 from Razor system running tftp:
MacOS Fusion 4: /Library/Preferences/VMware Fusion/vmnet8/dhcpd.conf

    filename "pxelinux.0";
    next-server ${razor_ipaddress};

Execute start_node.sh to launch nodejs web service.

## Environment Variables
* $RAZOR_HOME
    >Root directory for Razor install

* $RAZOR_RSPEC_WEBPATH
    >Root directory for dropping RSpec html _(optional)_

* $RAZOR_LOG_PATH
>Path for razor logs _(optional)_l
>>Default = $RAZOR_HOME/log

* $RAZOR_LOG_LEVEL
    > Verbosity for logs _(optional)_
    >> 0 = Debug
    >> 1 = Info
    >> 2 = Warn
    >> 3 = Error (default)
    >> 4 = Fatal
    >> 5 = Unknown

## Directory structure
    ./bin - control scripts
    ./conf - configuration YAML files
    ./doc - Documentation (YARD)
    ./images - default images directory
    ./install - installation bits
    ./lib - root library folder
    ./test_scripts - testing scripts
    ./rspec - unit tests (RSpec)

## Starting services

Start Razor API with:

    cd $RAZOR_HOME/bin/node
    node razor.js

## Notes
