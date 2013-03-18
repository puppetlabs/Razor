
require "project_razor"
require "rspec"



describe ProjectRazor::Engine do

  before (:all) do
    @data = ProjectRazor::Data.instance
    @data.check_init
    @config = ProjectRazor.config
    @engine = ProjectRazor::Engine.instance
    # Clean stuff out
    @data.delete_all_objects(:node)
  end

  after (:all) do
    # Clean out what we did
    @data.delete_all_objects(:node)
  end

  describe ".Node" do
    it "should be able to register a new node using hw_id" do
      node = ProjectRazor::Node.new({})
      node.hw_id << "AABBCCDDEEFF"
      node.hw_id << "112233445566"
      new_node = @engine.register_new_node_with_hw_id(node)
      new_node.class.should == ProjectRazor::Node
      new_node.hw_id.should == node.hw_id
      $node_uuid1 = new_node.uuid
      new_node.uuid.should == $node_uuid1
    end

    it "should be able to find node by hw_id" do
      find_node = @engine.lookup_node_by_hw_id(:hw_id => ["AABBCCDDEEFF"])
      find_node.uuid.should == $node_uuid1
      find_node = @engine.lookup_node_by_hw_id(:hw_id => ["112233445566"])
      find_node.uuid.should == $node_uuid1
      find_node = @engine.lookup_node_by_hw_id(:hw_id => ["AABBCCDDEEFF","112233445566"])
      find_node.uuid.should == $node_uuid1
      find_node = @engine.lookup_node_by_hw_id(:hw_id => ["1A2B3C4D5E6F"])
      find_node.should == nil
    end

    it "should be not be able to register a new node with a conflicting hw_id" do
      node = ProjectRazor::Node.new({})
      node.hw_id << "1A2B3C4D5E6F"
      node.hw_id << "112233445566"
      new_node = @engine.register_new_node_with_hw_id(node)
      new_node.should == nil
    end

    it "should auto-resolve duplicate hw_id's and remove the hw_id from the all but oldest node" do
      @data.delete_all_objects(:node)

      node3 = ProjectRazor::Node.new({})
      node3.hw_id << "FAKE"
      node3.hw_id << "CONFLICT"
      node3.timestamp = Time.now.to_i
      $node3_uuid = node3.uuid
      @data.persist_object(node3)

      sleep 1.5
      node4 = ProjectRazor::Node.new({})
      node4.hw_id << "HWID"
      node4.hw_id << "CONFLICT"
      node4.timestamp = Time.now.to_i
      $node4_uuid = node4.uuid
      @data.persist_object(node4)

      nodes = @data.fetch_all_objects(:node)
      nodes.sort! {|a,b| a.timestamp <=> b.timestamp}
      nodes.count.should == 2
      nodes[0].uuid.should == $node3_uuid
      nodes[1].uuid.should == $node4_uuid

      sleep 1.5
      node5 = ProjectRazor::Node.new({})
      node5.hw_id << "TEST"
      node5.hw_id << "NODE"
      node5.timestamp = Time.now.to_i
      $node5_uuid = node5.uuid
      new_node = @engine.register_new_node_with_hw_id(node5)
      new_node.uuid.should == $node5_uuid

      nodes = @data.fetch_all_objects(:node)
      nodes.sort! {|a,b| a.timestamp <=> b.timestamp}
      nodes.count.should == 3
      nodes[0].uuid.should == $node3_uuid
      nodes[1].uuid.should == $node4_uuid
      nodes[2].uuid.should == $node5_uuid
      nodes[0].hw_id.should == ["FAKE", "CONFLICT"]
      nodes[1].hw_id.should == ["HWID"]
      nodes[2].hw_id.should == ["TEST", "NODE"]

      find_node = @engine.lookup_node_by_hw_id(:hw_id => ["CONFLICT"])
      find_node.uuid.should == $node3_uuid
      find_node = @engine.lookup_node_by_hw_id(:hw_id => ["HWID"])
      find_node.uuid.should == $node4_uuid
      find_node = @engine.lookup_node_by_hw_id(:hw_id => ["TEST"])
      find_node.uuid.should == $node5_uuid
    end


  end
end
