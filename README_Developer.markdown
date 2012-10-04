# Developer README

This file is intended for developers for the Razor project.

## Dependencies

    git clone git@github.com:lynxbat/Razor.git
    cd Razor
    rvm install 1.9.3
    rvm use 1.9.3
    rvm gemset create razor
    rvm --create --rvmrc use ruby-1.9.3-p0@razor
    bundle install

## Testing

    rake spec
    rake spec_html

## PuppetLabs Acceptance Tests

Puppet has an acceptance test framework built to run tests on virtual hosts
out in the infrastructure; grab it from https://github.com/puppetlabs/puppet-acceptance

Once you have that you need to configure a node by their notes:

    HOSTS:
      razor-sut-ubuntu-1204-64.local:
        roles:
          - master
        platform:    ubuntu-12.04-amd64
        vmname:      razor-sut-ubuntu-1204-64
        fission:
          snapshot:  razor-test-base
    CONFIG:
      dummy: value

I use mDNS / Avahi on the node to locate it, and VMWare Fusion; you can
configure alternatives as per the notes in the puppet-acceptance project.

When you are ready, run the tests with:

    systest.rb --vmrun fusion -c razor.cfg --type manual -t ../razor/acceptance
