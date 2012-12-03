
require "project_razor"
require "rspec"
require "rz_rspec_matchers"
require "uuid"

# true == will remove all records from collection when done
# false == will leave them for debugging
CLEANUP = true

RSpec.configure do |config|
  config.include(RZRSpecMatchers)
end

describe ProjectRazor::Persist::Controller do
  before(:all) do
    @config = ProjectRazor::Config::Server.new
    @persist = ProjectRazor::Persist::Controller.new(@config)
  end

  after(:all) do
    @persist.teardown
  end

  describe ".Initialize" do
    it "should create a plug-in object for .database" do
      @persist.database.class.name.should end_with('Plugin')
    end
    it "should have stored config object and it should match" do
      #noinspection RubyResolve,RubyResolve
      @persist.config.should == @config
    end
    it "should have established a connection on initialization" do
      @persist.is_connected?.should == true
    end
  end

  describe ".Connection" do
    it "should connect to DatabaseEngine successfully using details in config" do
      @persist.is_connected?.should == true
    end
    it "should disconnect from DatabaseEngine successfully when teardown called" do
      @persist.check_connection.should == true  # make sure we have it open
      @persist.teardown  # do teardown
      @persist.is_connected?.should_not == true  # should be false now
    end
    it "should reconnect should the connection drop/timeout" do
      @persist.check_connection.should == true  # make sure we have it open
      @persist.teardown  # do teardown to break connection
      @persist.is_connected?.should_not == true  # make sure it is not connected
      @persist.check_connection.should == true  # should reconnect
    end
  end

  describe ".DatabaseBinding" do
    before(:each) do
      @persist.check_connection
    end
    it "should select/connect/bind to ProjectRazor database within DatabaseEngine successfully" do
      @persist.database.is_db_selected?.should == true
    end
  end

  describe ".Model" do
    before(:all) do
      #create junk model with random updates
      (0..rand(10)).each do
        |x|
        temp_model = ProjectRazor::ModelTemplate::Base.new({:@name => "rspec_junk#{x}", :@model_type => "base", :@values_hash => {"junk" => "1"}})
        temp_model._persist_ctrl = @persist
        (0..rand(10)).each do
          @persist.object_hash_update(temp_model.to_hash, :model)
        end
      end
      @model1 = ProjectRazor::ModelTemplate::Base.new({:@name => "rspec_modelname01", :@model_type => "base", :@values_hash => {"a" => "1"}})
      @model1._persist_ctrl = @persist
      @model2 = ProjectRazor::ModelTemplate::Base.new({:@name => "rspec_modelname02", :@uuid => @model1.uuid , :@model_type => "base", :@values_hash => {"a" => "454"}})
      @model2._persist_ctrl = @persist
      @model3 = ProjectRazor::ModelTemplate::Base.new({:@name => "rspec_modelname03", :@uuid => @model1.uuid , :@model_type => "base", :@values_hash => {"a" => "1000"}})
      @model3._persist_ctrl = @persist
    end

    after(:all) do
      if CLEANUP
        model_hash_array = @persist.object_hash_get_all(:model)
        model_hash_array.each do
          |model_hash|
          @persist.object_hash_remove(model_hash, :model)
        end
      end
    end


    it "should be able to add/update a Model to the Model collection" do
      @persist.object_hash_update(@model1.to_hash, :model)
      @persist.object_hash_update(@model2.to_hash, :model)
      @persist.object_hash_update(@model3.to_hash, :model)

      model_hash_array = @persist.object_hash_get_all(:model)
      # Check if model_hash_array contains a model with the 'uuid' that matches our object
      model_hash_array.should keys_with_values_count_equals({"@uuid" => @model1.uuid },1)
    end
    it "should see the last update to a Model in the collection and version number should be 3" do
      model_hash_array = @persist.object_hash_get_all(:model)
      model_hash_array.should keys_with_values_count_equals({"@uuid" => @model1.uuid , "@name" => "rspec_modelname03", "@version" => 3},1)
    end
    it "should return a array of Models from the Model collection without duplicates" do
      model_hash_array = @persist.object_hash_get_all(:model)
      model_hash_array.should keys_with_values_count_equals({"@uuid" => @model1.uuid },1)
    end
    it "should remove a Model from the Model collection" do
      @persist.object_hash_remove(@model3.to_hash, :model).should == true # should get positive return
      model_hash_array = @persist.object_hash_get_all(:model)
      model_hash_array.should keys_with_values_count_equals({"@uuid" => @model1.uuid },0)
    end
  end

  #describe ".Policy" do
  #  before(:all) do
  #    #create junk policies with random updates
  #    temp_model = ProjectRazor::Model::Base.new({:@name => "rspec_modelname01", :@model_type => "base", :@values_hash => {"a" => "1"}})
  #    (0..rand(10)).each do
  #      |x|
  #      temp_policy = ProjectRazor::Policy::Base.new({:@name => "rspec_policy_junk#{x}", :@model => temp_model.to_hash, :@policy_type => :unique})
  #      temp_policy._persist_ctrl = @persist
  #      (0..rand(10)).each do
  #        @persist.object_hash_update(temp_policy.to_hash, :policy)
  #      end
  #    end
  #    @policy1 = ProjectRazor::Policy::Base.new({:@name => "rspec_policy_name01", :@model => temp_model.to_hash, :@policy_type => :unique})
  #    @policy1._persist_ctrl = @persist
  #    @policy2 = ProjectRazor::Policy::Base.new({:@name => "rspec_policy_name02", :@uuid => @policy1.uuid , :@model => @policy1.model, :@policy_type => :unique})
  #    @policy2._persist_ctrl = @persist
  #    @policy3 = ProjectRazor::Policy::Base.new({:@name => "rspec_policy_name03", :@uuid => @policy1.uuid , :@model => @policy1.model, :@policy_type => :unique})
  #    @policy3._persist_ctrl = @persist
  #  end
  #
  #  after(:all) do
  #    if CLEANUP
  #      policy_hash_array = @persist.object_hash_get_all(:policy)
  #      policy_hash_array.each do
  #        |policy_hash|
  #        @persist.object_hash_remove(policy_hash, :policy)
  #      end
  #    end
  #  end
  #
  #  it "should be able to add/update a Policy to the Policy collection" do
  #    @persist.object_hash_update(@policy1.to_hash, :policy)
  #    @persist.object_hash_update(@policy2.to_hash, :policy)
  #    @persist.object_hash_update(@policy3.to_hash, :policy)
  #
  #    policy_hash_array = @persist.object_hash_get_all(:policy)
  #    # Check if policy_hash_array contains a Policy with the 'uuid' that matches our object
  #    policy_hash_array.should keys_with_values_count_equals({"@uuid" => @policy1.uuid },1)
  #  end
  #  it "should see the last update to a Policy in the collection and version number should be 3" do
  #    policy_hash_array = @persist.object_hash_get_all(:policy)
  #    policy_hash_array.should keys_with_values_count_equals({"@uuid" => @policy1.uuid , "@name" => @policy3.name, "@version" => 3},1)
  #  end
  #  it "should return a array of Policy from the Policy collection without duplicates" do
  #    policy_hash_array = @persist.object_hash_get_all(:policy)
  #    policy_hash_array.should keys_with_values_count_equals({"@uuid" => @policy1.uuid },1)
  #  end
  #  it "should remove a Policy from the Policy collection" do
  #    @persist.object_hash_remove(@policy3.to_hash, :policy).should == true # should get positive return
  #    policy_hash_array = @persist.object_hash_get_all(:policy)
  #    policy_hash_array.should keys_with_values_count_equals({"@uuid" => @policy1.uuid },0)
  #  end
  #end

  describe ".Node" do
    before(:all) do
      #create junk nodes with random updates
      (0..rand(10)).each do
        |x|
        temp_node = ProjectRazor::Node.new({:@name => "rspec_node_junk#{x}", :@last_state => :idle, :@current_state => :idle, :@next_state => :policy_applied})
        temp_node._persist_ctrl = @persist
        (0..rand(10)).each do
          @persist.object_hash_update(temp_node.to_hash, :node)
        end
      end
      @node1 = ProjectRazor::Node.new({:@name => "rspec_node_name01", :@last_state => :idle, :@current_state => :idle, :@next_state => :policy_applied})
      @node1._persist_ctrl = @persist
      @node2 = ProjectRazor::Node.new({:@name => "rspec_node_name02", :@uuid => @node1.uuid , :@last_state => :idle, :@current_state => :idle, :@next_state => :policy_applied})
      @node2._persist_ctrl = @persist
      @node3 = ProjectRazor::Node.new({:@name => "rspec_node_name03", :@uuid => @node1.uuid , :@last_state => :idle, :@current_state => :idle, :@next_state => :policy_applied})
      @node3._persist_ctrl = @persist
    end

    after(:all) do
      if CLEANUP
        #noinspection RubyResolve
        node_hash_array = @persist.object_hash_get_all(:node)
        node_hash_array.each do
          |node_hash|
          @persist.object_hash_remove(node_hash, :node)
        end
      end
    end

    it "should be able to add/update a Node to the Node collection" do
      @persist.object_hash_update(@node1.to_hash, :node)
      @persist.object_hash_update(@node2.to_hash, :node)
      @persist.object_hash_update(@node3.to_hash, :node)

      node_hash_array = @persist.object_hash_get_all(:node)
      # Check if node_hash_array contains a Node with the 'uuid' that matches our object
      node_hash_array.should keys_with_values_count_equals({"@uuid" => @node1.uuid },1)
    end
    it "should see the last update to a Node in the collection and version number should be 3" do
      node_hash_array = @persist.object_hash_get_all(:node)
      node_hash_array.should keys_with_values_count_equals({"@uuid" => @node1.uuid , "@name" => @node3.name, "@version" => 3},1)
    end
    it "should return a array of Node from the Node collection without duplicates" do
      node_hash_array = @persist.object_hash_get_all(:node)
      node_hash_array.should keys_with_values_count_equals({"@uuid" => @node1.uuid },1)
    end
    it "should remove a Node from the Node collection" do
      @persist.object_hash_remove(@node3.to_hash, :node).should == true # should get positive return
      node_hash_array = @persist.object_hash_get_all(:node)
      node_hash_array.should keys_with_values_count_equals({"@uuid" => @node1.uuid },0)
    end
  end
end
