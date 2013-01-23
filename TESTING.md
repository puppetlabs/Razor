Testing the Razor project
-------------------------

At the moment we have no real unit tests, just the acceptance tests.
Worse luck, those are fairly heavily tied to the Puppet Labs acceptance test
suite, so are not as easy to get going as you would like.

You can run the rspec suite - it is acceptance level - though:

1. Install `MongoDB` and have it running.
2. Install `nodejs` and `npm`.
3. Install the required node modules.  (See [the Puppet module for details](https://github.com/puppetlabs/puppetlabs-razor/blob/master/manifests/nodejs.pp))
4. Install the required gems.  (See [the Puppet module for details, again](https://github.com/puppetlabs/puppetlabs-razor/blob/master/manifests/ruby.pp))
5. Make sure you don't care about your data!  This will **DESTROY** the Razor database!
6. Run `rspec spec`

If you want to use our acceptance suite, which saves you destroying your local
data, you are welcome to.  It is not totally trivial to get working, but
should be possible even outside our staff.

1. Get a copy of the Razor git repo.  (`$REPO` will represent that in future.)
2. Get a copy of the [puppet-acceptance](https://github.com/puppetlabs/puppet-acceptance) git repository.
3. Follow their documentation for which VM systems work, and how to interface with them.
4. Build a new Ubuntu 12.04 64-bit VM, bare bones, nothing installed but the base system.
5. Create a snapshot named something like `razor-test-base`.  (Shut off the VM while you do this.)
6. Modify the configuration file in `acceptance/razor-acceptance.cfg` for your VM system.
7. Grab the latest successful artifact from [the Puppet module build CI system](https://jenkins.puppetlabs.com/job/Puppet%20Module%20-%20razor%20-%20package%20build/)
8. Put that as the *only* tarball in `$REPO/pkg`
9. Run something akin it `cd $REPO && WORKSPACE=$REPO ../puppet-acceptance/systest.rb --vmrun fusion -c local-acceptance.cfg --type manual -t acceptance --debug`

That *should* go through, build, and test everything for you.
