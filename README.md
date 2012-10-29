# Project Razor

[![Build Status](https://jenkins.puppetlabs.com/job/Razor%20Acceptance/badge/icon)](https://jenkins.puppetlabs.com/job/Razor%20Acceptance/)

## Introduction

Project Razor is a power control, provisioning, and management application
designed to deploy both bare-metal and virtual computer resources. Razor
provides broker plugins for integration with third party such as Puppet.

This is a 0.x release, so the CLI and API is still in flux and may
change. Make sure you __read the release notes before upgrading__

Project Razor is versioned with [semantic versioning][semver], and we follow
the precepts of that document.  Right now that means that breaking changes are
permitted to both the API and internals, although we try to keep compatibility
as far as reasonably possible.


## How to Get Help

We really want Razor to be simple to contribute to, and to ensure that you can
get started quickly.  A big part of that is being available to help you figure
out the right way to solve a problem, and to make sure you get up to
speed quickly.

You can always reach out and ask for help:

* by email or through the web on the [puppet-razor@googlegroups.com][puppet-razor]
  mailing list.  (membership is required to post.)
* by IRC, through [#puppet-razor][irc] on [freenode][freenode].

If you want to help improve Razor directly we have a
[fairly detailed CONTRIBUTING guide in the repository][contrib] that you can
use to understand how code gets in to the system, how the project runs, and
how to make changes yourself.

We welcome contributions at all levels, including working strictly on our
documentation, tests, or code contributions.  We also welcome, and value,
input about your experiences with Project Razor, and provisioning in general,
on the mailing list as we discuss how the project should solve problems.


## Installation

* Razor Overview: [Nickapedia.com](http://nickapedia.com/2012/05/21/lex-parsimoniae-cloud-provisioning-with-a-razor)
* Razor Session from PuppetConf 2012: [Youtube](http://www.youtube.com/watch?v=cR1bOg0IU5U)

Follow wiki documentation for installation process:

https://github.com/puppetlabs/Razor/wiki/installation

## Project Committers

This is the official list of users with "committer" rights to the
Razor project.  [For details on what that means, see the CONTRIBUTING
guide in the repository][contrib]

* [Daniel Pittman](https://github.com/daniel-pittman)
* [Nicholas Weaver](https://github.com/lynxbat)
* [Tom McSweeney](https://github.com/tjmcs)
* [Nan Liu](https://github.com/nanliu)

If you can't figure out who to contact,
[Daniel Pittman](https://github.com/daniel-pittman) is the best first point of
contact for the project.  (Find me at Daniel Pittman <daniel@puppetlabs.com>,
or dpittman on the `#puppet-razor` IRC channel.)

This is a hand-maintained list, thanks to the limits of technology.
Please let [Daniel Pittman](https://github.com/daniel-pittman) know if you run
into any errors or omissions in that list.


## Razor MicroKernel
* The Razor MicroKernel project:
[https://github.com/puppetlabs/Razor-Microkernel](https://github.com/puppetlabs/Razor-Microkernel)
* The Razor MK images are officially available at:
[https://github.com/puppetlabs/Razor-Microkernel/downloads](https://github.com/puppetlabs/Razor-Microkernel/downloads)

## Environment Variables
* $RAZOR\_HOME: Razor installation root directory.
* $RAZOR\_RSPEC\_WEBPATH: _optional_ rspec HTML output path.
* $RAZOR\_LOG\_PATH: _optional_ Razor log directory (default: ${RAZOR_HOME}/log).
* $RAZOR\_LOG\_LEVEL: _optional_ Razor log output verbosity level:

        0 = Debug
        1 = Info
        2 = Warn
        3 = Error (default)
        4 = Fatal
        5 = Unknown

## Starting services

Start Razor API with:

    cd $RAZOR_HOME/bin
    ./razor_daemon.rb start

## License

Project Razor is distributed under the Apache 2.0 license.
See [the LICENSE file][license] for full details.

## Reference

* Razor Overview: [Nickapedia.com](http://nickapedia.com/2012/05/21/lex-parsimoniae-cloud-provisioning-with-a-razor)
* Puppet Labs Razor Module:[Puppetlabs.com](http://puppetlabs.com/blog/introducing-razor-a-next-generation-provisioning-solution/)


[puppet-razor]: https://groups.google.com/forum/?fromgroups#!forum/puppet-razor
[irc]:          https://webchat.freenode.net/?channels=puppet-razor
[freenode]:     http://freenode.net/
[contrib]:      https://github.com/puppetlabs/Razor/blob/master/CONTRIBUTING.md
[license]:      https://github.com/puppetlabs/Razor/blob/master/LICENSE
[semver]:       http://semver.org/
