
require "project_razor"
require "rspec"
require "fileutils"

PC_TIMEOUT = 3 # timeout for our connection to DB, using to make quicker tests
NODE_COUNT = 5 # total amount of nodes to use for node testing

def default_config
  ProjectRazor::Config::Server.new
end


def write_config(config)
  # First delete any existing default config
  File.delete($config_server_path) if File.exists?($config_server_path)
  # Now write out the default config above
  f = File.open($config_server_path, 'w+')
  f.write(YAML.dump(config))
  f.close
end


describe ProjectRazor::Data do

  describe ".Config" do
    before(:all) do
      #Backup existing razor_server.conf being nice to the developer's environment
      FileUtils.mv($config_server_path, "#{$config_server_path}.backup", :force => true) if File.exists?($config_server_path)
    end

    after(:all) do
      #Restore razor_server.conf back
      if File.exists?("#{$config_server_path}.backup")
        File.delete($config_server_path)
        FileUtils.mv("#{$config_server_path}.backup", $config_server_path, :force => true) if File.exists?("#{$config_server_path}.backup")
      else
        write_config(default_config)
      end

    end

    it "should load a config from config path(#{$config_server_path}) on init" do
      config = default_config
      config.persist_host = "127.0.0.1"
      config.persist_mode = :mongo
      config.persist_port = 27017
      config.admin_port = (rand(1000)+1).to_s
      config.api_port = (rand(1000)+1).to_s
      config.persist_timeout = PC_TIMEOUT
      config.rz_mk_boot_debug_level = "quiet"
      config.rz_mk_boot_kernel_args = "console=ttyS0"
      write_config(config)

      data = ProjectRazor::Data.instance
      data.check_init

      # Check to make sure it is our config object
      data.config.admin_port.should == config.admin_port
      data.config.api_port.should == config.api_port
      data.config.rz_mk_boot_debug_level.should == config.rz_mk_boot_debug_level
      data.config.rz_mk_boot_kernel_args.should == config.rz_mk_boot_kernel_args


      # confirm the reverse that nothing is default
      data.config.admin_port.should_not == default_config.admin_port
      data.config.api_port.should_not == default_config.api_port
      data.config.rz_mk_boot_debug_level.should_not == default_config.rz_mk_boot_debug_level
      data.config.rz_mk_boot_kernel_args.should_not == default_config.rz_mk_boot_kernel_args

    end

    it "should create a default config object and new config file if there is none at default path" do
      # Delete the existing file
      File.delete($config_server_path) if File.exists?($config_server_path)
      File.exists?($config_server_path).should == false

      data = ProjectRazor::Data.instance
      data.check_init

      # Confirm we have our default config
      data.config.instance_variables.each do
      |iv|
        # Loop and make sure each object matches
        data.config.instance_variable_get(iv).should == default_config.instance_variable_get(iv)
      end

      #Confirm we have our default file
      File.exists?($config_server_path).should == true
      data.persist_ctrl.teardown
    end

    it "should create a default config object if the YAML config has format errors" do
      temp_str = "--- !r*by/object:RZConfition\n\n\npersist_mode: :mongo\npersist_port: '27017'\nadmin_port: '8017'\ndddpersist_host: 127.0.0.1\ndddapi_port: '8026'\n"
      write_config(temp_str)
      File.exists?($config_server_path).should == true

      data = ProjectRazor::Data.instance
      data.check_init

      # Confirm we have our default config
      data.config.instance_variables.each do
      |iv|
        # Loop and make sure each object matches
        data.config.instance_variable_get(iv).should == default_config.instance_variable_get(iv)
      end
      data.persist_ctrl.teardown
    end

    it "should create a default config object if the YAML config creates any nil instance variables because of malformed YAML" do
      temp_str = "--- !ruby/object:ProjectRazor::Config::Server\npersist_mode: :mongo\nDdDpersist_port: '27017'\ndDdadmin_port: '8017'\npersist_host: 127.0.0.1\napi_port: '8026'\n"
      write_config(temp_str)
      File.exists?($config_server_path).should == true

      data = ProjectRazor::Data.instance
      data.check_init

      # Confirm we have our default config
      data.config.instance_variables.each do
      |iv|
        # Loop and make sure each object matches
        data.config.instance_variable_get(iv).should == default_config.instance_variable_get(iv)
      end
      data.persist_ctrl.teardown
    end

  end

  describe ".PersistenceController" do

    before(:all) do
      @data = ProjectRazor::Data.instance
      @data.check_init
    end

    after(:all) do
      @data.teardown
    end


    it "should create an Persistence Controller object with passed config" do
      @data.persist_ctrl.kind_of?(ProjectRazor::Persist::Controller).should == true
    end

    it "should have an active Persistence Controller connection" do
      @data.persist_ctrl.is_connected?.should == true
    end

  end


  describe ".Nodes" do

    before(:all) do
      @data = ProjectRazor::Data.instance
      @data.check_init
      @data.delete_all_objects(:node)

      (1..NODE_COUNT).each do
      |x|
        temp_node = ProjectRazor::Node.new({:@name => "rspec_node_junk#{x}", :@last_state => :idle, :@current_state => :idle, :@next_state => :policy_applied})
        temp_node = @data.persist_object(temp_node)
        @last_uuid = temp_node.uuid
        #(0..rand(10)).each do
        temp_node.update_self
        #end
      end
    end

    after(:all) do
      @data.persist_ctrl.object_hash_remove_all(:node).should == true
      @data.teardown
    end

    it "should have a list of Nodes" do
      nodes = @data.fetch_all_objects(:node)
      nodes.count.should == NODE_COUNT
    end

    it "should get a single node by UUID" do
      node = @data.fetch_object_by_uuid(:node, @last_uuid)
      node.is_a?(ProjectRazor::Node).should == true

      node = @data.fetch_object_by_uuid(:node, "12345")
      node.is_a?(NilClass).should == true
    end

    it "should be able to add a new Node (does not exist) and update" do
      temp_node = ProjectRazor::Node.new({:@name => "rspec_node_junk_new", :@last_state => :idle, :@current_state => :idle, :@next_state => :policy_applied})
      temp_node = @data.persist_object(temp_node)
      temp_node.update_self

      node = @data.fetch_object_by_uuid(:node, temp_node.uuid)
      node.version.should == 2
    end

    it "should be able to delete a specific Node by uuid" do
      temp_node = ProjectRazor::Node.new({:@name => "rspec_node_junk_delete_uuid", :@last_state => :idle, :@current_state => :idle, :@next_state => :policy_applied})
      temp_node = @data.persist_object(temp_node)
      temp_node.update_self

      node = @data.fetch_object_by_uuid(:node, temp_node.uuid)
      node.version.should == 2

      @data.delete_object_by_uuid(node._namespace, node.uuid).should == true
      @data.fetch_object_by_uuid(:node, node.uuid).should == nil
    end

    it "should be able to delete a specific Node by object" do
      temp_node = ProjectRazor::Node.new({:@name => "rspec_node_junk_delete_object", :@last_state => :idle, :@current_state => :idle, :@next_state => :policy_applied})
      temp_node = @data.persist_object(temp_node)
      temp_node.update_self

      node = @data.fetch_object_by_uuid(:node, temp_node.uuid)
      node.version.should == 2

      @data.delete_object(node).should == true
      @data.fetch_object_by_uuid(:node, node.uuid).should == nil
    end

    it "should be able to update Node attributes for existing Node" do
      node = @data.fetch_object_by_uuid(:node, @last_uuid)
      node.is_a?(ProjectRazor::Node).should == true
      node.attributes_hash = {:hostname => "nick_weaver", :ip_address => "1.1.1.1", :iq => 160}
      node.update_self
      node.attributes_hash["hostname"].should == "nick_weaver"
      node.attributes_hash["ip_address"].should == "1.1.1.1"
      node.attributes_hash["iq"].should == 160

      node_confirm = @data.fetch_object_by_uuid(:node, @last_uuid)
      node_confirm.is_a?(ProjectRazor::Node).should == true
      node_confirm.attributes_hash["hostname"].should == "nick_weaver"
      node_confirm.attributes_hash["ip_address"].should == "1.1.1.1"
      node_confirm.attributes_hash["iq"].should == 160
    end

    it "should be able to update the LastState for existing Node" do
      node = @data.fetch_object_by_uuid(:node, @last_uuid)
      node.is_a?(ProjectRazor::Node).should == true
      node.last_state = :nick
      node.update_self
      node.last_state.should == :nick

      node_confirm = @data.fetch_object_by_uuid(:node, @last_uuid)
      node_confirm.is_a?(ProjectRazor::Node).should == true
      node_confirm.last_state = :nick
    end

    # the "current_state=" and "next_state=" methods no longer exist in
    # the ProjectRazor::Node object; so these tests are no longer valid
    #it "should be able to update the CurrentState for existing Node" do
    #  node = @data.fetch_object_by_uuid(:node, @last_uuid)
    #  node.is_a?(ProjectRazor::Node).should == true
    #  node.current_state = :nick
    #  node.update_self
    #  node.current_state.should == :nick
    #
    #  node_confirm = @data.fetch_object_by_uuid(:node, @last_uuid)
    #  node_confirm.is_a?(ProjectRazor::Node).should == true
    #  node_confirm.current_state = :nick
    #end
    #
    #it "should be able to update the NextState for existing Node" do
    #  node = @data.fetch_object_by_uuid(:node, @last_uuid)
    #  node.is_a?(ProjectRazor::Node).should == true
    #  node.next_state = :nick
    #  node.update_self
    #  node.next_state.should == :nick
    #
    #  node_confirm = @data.fetch_object_by_uuid(:node, @last_uuid)
    #  node_confirm.is_a?(ProjectRazor::Node).should == true
    #  node_confirm.next_state = :nick
    #end

    it "should be able to delete all Nodes" do
      @data.delete_all_objects(:node)
      @data.fetch_all_objects(:node).count.should == 0
    end

  end

  #describe ".Models" do
  #
  #  before(:all) do
  #    @data = ProjectRazor::Data.instance
  #    @data.check_init
  #
  #    (1..NODE_COUNT).each do
  #    |x|
  #      temp_model = ProjectRazor::Model::Base.new({:@name => "rspec_model_junk#{x}", :@model_type => :base, :@values_hash => {}})
  #      temp_model = @data.persist_object(temp_model)
  #      @last_uuid = temp_model.uuid
  #      #(0..rand(10)).each do
  #      temp_model.update_self
  #      #end
  #    end
  #  end
  #
  #  after(:all) do
  #    @data.persist_ctrl.object_hash_remove_all(:model).should == true
  #    @data.teardown
  #  end
  #
  #  it "should have a list of Models" do
  #    models = @data.fetch_all_objects(:model)
  #    models.count.should == NODE_COUNT
  #  end
  #
  #  it "should get a single model by UUID" do
  #    model = @data.fetch_object_by_uuid(:model, @last_uuid)
  #    model.is_a?(ProjectRazor::Model::Base).should == true
  #
  #    model = @data.fetch_object_by_uuid(:model, "12345")
  #    model.is_a?(NilClass).should == true
  #  end
  #
  #  it "should be able to add a new Model (does not exist) and update" do
  #    temp_model = ProjectRazor::Model::Base.new({:@name => "rspec_model_junk_new", :@last_state => :idle, :@current_state => :idle, :@next_state => :policy_applied})
  #    temp_model = @data.persist_object(temp_model)
  #    temp_model.update_self
  #
  #    model = @data.fetch_object_by_uuid(:model, temp_model.uuid)
  #    model.version.should == 2
  #  end
  #
  #  it "should be able to delete a specific Model by uuid" do
  #    temp_model = ProjectRazor::Model::Base.new({:@name => "rspec_model_junk_delete_uuid", :@last_state => :idle, :@current_state => :idle, :@next_state => :policy_applied})
  #    temp_model = @data.persist_object(temp_model)
  #    temp_model.update_self
  #
  #    model = @data.fetch_object_by_uuid(:model, temp_model.uuid)
  #    model.version.should == 2
  #
  #    @data.delete_object_by_uuid(model._namespace, model.uuid).should == true
  #    @data.fetch_object_by_uuid(:model, model.uuid).should == nil
  #  end
  #
  #  it "should be able to delete a specific Model by object" do
  #    temp_model = ProjectRazor::Model::Base.new({:@name => "rspec_model_junk_delete_object", :@last_state => :idle, :@current_state => :idle, :@next_state => :policy_applied})
  #    temp_model = @data.persist_object(temp_model)
  #    temp_model.update_self
  #
  #    model = @data.fetch_object_by_uuid(:model, temp_model.uuid)
  #    model.version.should == 2
  #
  #    @data.delete_object(model).should == true
  #    @data.fetch_object_by_uuid(:model, model.uuid).should == nil
  #  end
  #
  #  it "should be able to update Model attributes for existing Model" do
  #    model = @data.fetch_object_by_uuid(:model, @last_uuid)
  #    model.is_a?(ProjectRazor::Model::Base).should == true
  #    model.values_hash = {:hostname => "nick_weaver", :ip_address => "1.1.1.1", :iq => 160}
  #    model.update_self
  #    model.values_hash["hostname"].should == "nick_weaver"
  #    model.values_hash["ip_address"].should == "1.1.1.1"
  #    model.values_hash["iq"].should == 160
  #
  #    model_confirm = @data.fetch_object_by_uuid(:model, @last_uuid)
  #    model_confirm.is_a?(ProjectRazor::Model::Base).should == true
  #    model_confirm.values_hash["hostname"].should == "nick_weaver"
  #    model_confirm.values_hash["ip_address"].should == "1.1.1.1"
  #    model_confirm.values_hash["iq"].should == 160
  #  end
  #
  #  it "should be able to update the LastState for existing Model" do
  #    model = @data.fetch_object_by_uuid(:model, @last_uuid)
  #    model.is_a?(ProjectRazor::Model::Base).should == true
  #    model.model_type = :nick
  #    model.update_self
  #    model.model_type.should == :nick
  #
  #    model_confirm = @data.fetch_object_by_uuid(:model, @last_uuid)
  #    model_confirm.is_a?(ProjectRazor::Model::Base).should == true
  #    model_confirm.model_type = :nick
  #  end
  #
  #
  #  it "should be able to delete all Models" do
  #    @data.delete_all_objects(:model)
  #    @data.fetch_all_objects(:model).count.should == 0
  #  end
  #
  #end

  # No Policy unit tests until done with refactor
  #describe ".Policies" do
  #
  #  before(:all) do
  #    @data = ProjectRazor::Data.instance
  #    @data.check_init
  #
  #    (1..NODE_COUNT).each do
  #    |x|
  #      temp_policy = ProjectRazor::Policy::Base.new({:@name => "rspec_policy_junk#{x}", :@policy_type => :base, :@model => :base})
  #      temp_policy = @data.persist_object(temp_policy)
  #      @last_uuid = temp_policy.uuid
  #      #(0..rand(10)).each do
  #      temp_policy.update_self
  #      #end
  #    end
  #  end
  #
  #  after(:all) do
  #    @data.persist_ctrl.object_hash_remove_all(:policy).should == true
  #    @data.teardown
  #  end
  #
  #  it "should have a list of Policies" do
  #    policies = @data.fetch_all_objects(:policy)
  #    policies.count.should == NODE_COUNT
  #  end
  #
  #  it "should get a single policy by UUID" do
  #    policy = @data.fetch_object_by_uuid(:policy, @last_uuid)
  #    policy.is_a?(ProjectRazor::Policy::Base).should == true
  #
  #    policy = @data.fetch_object_by_uuid(:policy, "12345")
  #    policy.is_a?(NilClass).should == true
  #  end
  #
  #  it "should be able to add a new Policy (does not exist) and update" do
  #    temp_policy = ProjectRazor::Policy::Base.new({:@name => "rspec_policy_junk_new", :@last_state => :idle, :@current_state => :idle, :@next_state => :policy_applied})
  #    temp_policy = @data.persist_object(temp_policy)
  #    temp_policy.update_self
  #
  #    policy = @data.fetch_object_by_uuid(:policy, temp_policy.uuid)
  #    policy.version.should == 2
  #  end
  #
  #  it "should be able to delete a specific Policy by uuid" do
  #    temp_policy = ProjectRazor::Policy::Base.new({:@name => "rspec_policy_junk_delete_uuid", :@last_state => :idle, :@current_state => :idle, :@next_state => :policy_applied})
  #    temp_policy = @data.persist_object(temp_policy)
  #    temp_policy.update_self
  #
  #    policy = @data.fetch_object_by_uuid(:policy, temp_policy.uuid)
  #    policy.version.should == 2
  #
  #    @data.delete_object_by_uuid(policy._namespace, policy.uuid).should == true
  #    @data.fetch_object_by_uuid(:policy, policy.uuid).should == nil
  #  end
  #
  #  it "should be able to delete a specific Policy by object" do
  #    temp_policy = ProjectRazor::Policy::Base.new({:@name => "rspec_policy_junk_delete_object", :@last_state => :idle, :@current_state => :idle, :@next_state => :policy_applied})
  #    temp_policy = @data.persist_object(temp_policy)
  #    temp_policy.update_self
  #
  #    policy = @data.fetch_object_by_uuid(:policy, temp_policy.uuid)
  #    policy.version.should == 2
  #
  #    @data.delete_object(policy).should == true
  #    @data.fetch_object_by_uuid(:policy, policy.uuid).should == nil
  #  end
  #
  #  it "should be able to update Policy attributes for existing Policy" do
  #    policy = @data.fetch_object_by_uuid(:policy, @last_uuid)
  #    policy.is_a?(ProjectRazor::Policy::Base).should == true
  #    policy.model = :nick
  #    policy.update_self
  #
  #    policy_confirm = @data.fetch_object_by_uuid(:policy, @last_uuid)
  #    policy_confirm.is_a?(ProjectRazor::Policy::Base).should == true
  #    policy_confirm.model.should == :nick
  #  end
  #
  #  it "should be able to update the LastState for existing Policy" do
  #    policy = @data.fetch_object_by_uuid(:policy, @last_uuid)
  #    policy.is_a?(ProjectRazor::Policy::Base).should == true
  #    policy.policy_type = :nick
  #    policy.update_self
  #    policy.policy_type.should == :nick
  #
  #    policy_confirm = @data.fetch_object_by_uuid(:policy, @last_uuid)
  #    policy_confirm.is_a?(ProjectRazor::Policy::Base).should == true
  #    policy_confirm.policy_type = :nick
  #  end
  #
  #
  #  it "should be able to delete all Policies" do
  #    @data.delete_all_objects(:policy)
  #    @data.fetch_all_objects(:policy).count.should == 0
  #  end
  #
  #end

end
