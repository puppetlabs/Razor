require 'spec_helper'
require 'project_razor/config/server'

require 'tempfile'
require 'yaml'

describe ProjectRazor::Config::Server do
  # @todo danielp 2013-03-13: these two hooks are required because we use a
  # global variable to manage the filename.  That shouldn't persist, but it
  # does, and so here we are.
  before :each do
    @saved_config_server_path = $config_server_path
    # Since we only run on Unix, this should be portable enough.
    $config_server_path = '/dev/empty'

    # This runs *after* the global configuration, which resets our state to
    # "blank" and allows our tests to function.  This comment, my friends,
    # is why we shouldn't write stateful code.
    ProjectRazor::Config::Server._reset_instance
  end

  after :each do
    $config_server_path = @saved_config_server_path
    @saved_config_server_path = nil

    ProjectRazor::Config::Server._reset_instance
  end

  context "class" do
    subject { ProjectRazor::Config::Server }
    it { should respond_to "instance" }
  end

  describe ".instance" do
    it "should return the same instance if called twice" do
      ProjectRazor::Config::Server.instance.object_id.should ==
        ProjectRazor::Config::Server.instance.object_id
    end

    it "should load the configuration file doesn't exist" do
      unexists = Tempfile.new('this-file-does-not-exist')
      File.unlink(unexists.path) # whee

      $config_server_path = unexists.path
      File.should_not exist $config_server_path # belt
      ProjectRazor::Config::Server.instance.    # ...and britches
        should be_an_instance_of ProjectRazor::Config::Server
    end

    it "should create an instance if the configuration is not YAML" do
      not_yaml = "}}} this is definitely not valid YAML {{{"
      # This might seem a paranoid check, but there are many different YAML
      # parsers for Ruby, and some of them have decided that all sorts of
      # random things will suddenly be acceptable in the past.
      #
      # Think of this as checking my assumptions about the YAML parser, not
      # checking that the YAML parser behaves as specified.  (Because,
      # remember, this is Ruby, so the documentation for the YAML class is
      # zero lines long. ;)
      expect { YAML.load(not_yaml) }.to raise_error

      Tempfile.open('this-config-file-is-not-yaml') do |file|
        file.puts not_yaml
        file.flush
        file.fsync rescue nil   # can't do much if this fails

        $config_server_path = file.path
        ProjectRazor::Config::Server.instance.
          should be_an_instance_of ProjectRazor::Config::Server
      end
    end

    it "should create a correct instance if the YAML has the wrong class tagged" do
      Tempfile.open('this-config-file-has-the-wrong-class') do |file|
        file.puts YAML.dump({ 1..10 => 10..1 })
        file.flush
        file.fsync rescue nil   # can't do much if this fails

        $config_server_path = file.path
        ProjectRazor::Config::Server.instance.
          should be_an_instance_of ProjectRazor::Config::Server
      end
    end

    it "should upgrade an instance with a missing value" do
      # What is this, I don't even...
      Tempfile.open('this-config-file-has-missing-values') do |file|
        file.puts <<YAML
--- !ruby/object:ProjectRazor::Config::Server
image_svc_host: 8.8.8.8
YAML
        file.flush
        file.fsync rescue nil   # can't do much if this fails

        $config_server_path = file.path
        config = ProjectRazor::Config::Server.instance
        config.image_svc_host.should == '8.8.8.8' # present, and...
        config.persist_port.should   == 27017     # ...missing
      end
    end

    # I don't think this is a good idea, but it is the current semantics, so
    # we should totally test the darn thing.
    it "should create the config file on disk if it was missing" do
      unexists = Tempfile.new('this-file-does-not-exist')
      File.unlink(unexists.path) # whee

      $config_server_path = unexists.path
      File.should_not exist $config_server_path # belt
      ProjectRazor::Config::Server.instance.    # ...and britches
        should be_an_instance_of ProjectRazor::Config::Server
      File.should exist unexists.path
    end
  end

  describe "defaults" do
    subject('defaults') { ProjectRazor::Config::Server.instance.defaults }
    it { should be_an_instance_of Hash }
    it { should include 'image_svc_host' }

    it "should get the local IP for the default image_svc_host" do
      defaults['image_svc_host'].
        should == ProjectRazor::Config::Server.instance.get_an_ip
    end

    it "should default to mongodb" do
      defaults['persist_mode'].should == :mongo
    end
  end

  describe "save_as_yaml" do
    it "should silently skip if the file exists" do
      # This depends on the current behaviour of creating the file if it
      # didn't already exist.  That probably isn't wise, long term.
      unexists = Tempfile.new('this-file-does-not-exist')
      File.unlink(unexists.path) # whee
      $config_server_path = unexists.path
      ProjectRazor::Config::Server.instance.should be
      File.should exist unexists.path

      # OK, we are set up, thanks hideous stateful object.  Now, fill the file
      # with our test content.
      File.unlink(unexists.path)
      File.open(unexists.path, 'w') {|fh| fh.print "placeholder" }

      # OK, try saving over that, eh?
      ProjectRazor::Config::Server.instance.save_as_yaml(unexists.path)

      # ...did that happen?
      File.read(unexists.path).should == "placeholder"
    end
  end
end
