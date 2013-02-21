Testing the Razor project
-------------------------

There are two collections of tests in the Razor project, our unit tests, and the acceptance tests.

## Unit Tests

The unit test suite is kind of incomplete right now - most of it is
placeholders that do nothing beyond a syntax check.  You should still run it
before you submit something, though, since it is better than no checking.

To run that:

    rspec spec  # whee!


## Acceptance Tests

You can run the acceptance rspec suite fairly easily:

1. Install `MongoDB` and have it running.
2. Install `nodejs` and `npm`.
3. Install the required node modules.  (See [the Puppet module for details](https://github.com/puppetlabs/puppetlabs-razor/blob/master/manifests/nodejs.pp))
4. Install the required gems.  (See [the Puppet module for details, again](https://github.com/puppetlabs/puppetlabs-razor/blob/master/manifests/ruby.pp))
5. Make sure you don't care about your data!  This will **DESTROY** the Razor database!
6. Start razor with `/opt/razor/bin/razor_daemons.rb start`
7. Run `rspec acceptance/spec`

If you want to use our full acceptance suite, which saves you destroying your
local data, and provides a bunch of valuable additional testing you are
welcome to.  It is not totally trivial to get working, but should be possible
even outside our offices:

1. Get a copy of the Razor git repo.  (`$REPO` will represent that in future.)
2. Get a copy of the [puppet-acceptance](https://github.com/puppetlabs/puppet-acceptance) git repository.
3. Follow their documentation for which VM systems work, and how to interface with them.
4. Build a new Ubuntu 12.04 64-bit VM, bare bones, nothing installed but the base system.
5. Create a snapshot named something like `razor-test-base`.  (Shut off the VM while you do this.)
6. Modify the configuration file in `acceptance/razor-acceptance.cfg` for your VM system.
7. Grab the latest successful artifact from [the Puppet module build CI system](https://jenkins.puppetlabs.com/job/Puppet%20Module%20-%20razor%20-%20package%20build/)
8. Put that as the *only* tarball in `$REPO/pkg`
9. Run something akin it `cd $REPO && WORKSPACE=$REPO ../puppet-acceptance/systest.rb --vmrun fusion -c local-acceptance.cfg --type manual -t acceptance --debug`

That *should* go through, build, and test everything for you.  Ask on the mailing list if it isn't sufficient to get a test run going.

