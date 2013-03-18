
require "project_razor"
require "rspec"
require "net/http"
require "net/http"
require "json"

describe ProjectRazor::Engine do

  before (:all) do
    @data = ProjectRazor::Data.instance
    @data.check_init
    @config = ProjectRazor.config
    @engine = ProjectRazor::Engine.instance

    # Clean stuff out
    @data.delete_all_objects(:node)
    @data.delete_all_objects(:policy)
    @data.delete_all_objects(:active)
    @data.delete_all_objects(:tag)
  end

  after (:all) do
    # Clean out what we did
    @data.delete_all_objects(:node)
    @data.delete_all_objects(:policy)
    @data.delete_all_objects(:active)
    @data.delete_all_objects(:tag)
  end

  describe ".MK" do

    it "should send a register command to an unknown node" do
      @engine.mk_checkin("123456789", "idle").should == {"command_name"=>:register, "command_param"=>{}}
    end

    it "should tell a known node that has not checked-in within the register_timeout window to register" do


      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/node/register" # root URI for node slice actions


      state = "idle"

      json_hash = {}
      json_hash["@uuid"] = "01234567890"
      json_hash["@last_state"] = state
      json_hash["@attributes_hash"] = {"hostname" => "rspec.engine.testing.local",
                                       "ip_address" => "1.1.1.1"}

      json_string = JSON.generate(json_hash)
      res = Net::HTTP.post_form(uri, 'json_hash' => json_string)
      response_hash = JSON.parse(res.body)

      response_hash['errcode'].should == 0
      $node_uuid = response_hash['response']['@uuid']

      node = @data.fetch_object_by_uuid(:node, $node_uuid)
      node.timestamp = (Time.now.to_i - @config.register_timeout) - 1
      node.update_self

      @engine.mk_checkin($node_uuid, "idle").should == {"command_name"=>:register, "command_param"=>{}}
    end

    it "should tell a known node with regular checkin and no applicable policy: acknowledge" do
      @engine.mk_checkin($node_uuid, "idle").should == {"command_name"=>:acknowledge, "command_param"=>{}}
    end

    it "should bind a policy to a known node who is tagged to a matching rule (single tag node, single tag rule)" do

      ### This test is rather complex - it is built off logic in slice_tag

      #### We create an empty tag rule with the tag: RSPEC_ENGINE
      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/tag"
      name = "live_test_tag_rule_for_engine"
      tag = "RSPEC_ENGINE"
      json_hash = {}
      json_hash["@name"] = name
      json_hash["@tag"] = tag
      json_hash["@tag_matchers"] = []
      json_string = JSON.generate(json_hash)
      res = Net::HTTP.post_form(uri, 'json_hash' => json_string)
      response_hash = JSON.parse(res.body)
      live_tag_rule_uuid = response_hash['response'][0]['@uuid']


      # We add one tag matchers to it
      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/tag/#{live_tag_rule_uuid}/matcher"
      json_hash = {}
      json_hash["@tag_rule_uuid"] = live_tag_rule_uuid
      json_hash["@key"] = "hostname"
      json_hash["@value"] = "rspec.engine.testing.local"
      json_hash["@compare"] = "equal"
      json_hash["@inverse"] = "false"
      json_string = JSON.generate(json_hash)
      Net::HTTP.post_form(uri, 'json_hash' => json_string)


      # Confirm the tag rule and tag matcher within the rule got placed
      tag_rules = @data.fetch_all_objects(:tag)
      tag_rules.count.should == 1
      tag_rules[0].tag_matchers.count.should == 1

      # Get out node
      node = @data.fetch_object_by_uuid(:node, $node_uuid)
      # Make sure our tag is applied dynamically
      node.tags.should == %W(RSPEC_ENGINE)

      # Create a new policy rule
      new_policy = ProjectRazor::PolicyTemplate::LinuxDeploy.new({})
      new_policy.label = "Base Swift Servers - Ubuntu 11.10"
      new_policy.model = ProjectRazor::ModelTemplate::Base.new({})
      new_policy.enabled = true
      new_policy.tags << "RSPEC_ENGINE"


      # Make sure we have no policy rules
      @engine.policies.get.count.should == 0

      # We add our policy rule
      @engine.policies.add(new_policy)

      # Confirm it is there
      @engine.policies.get.count.should == 1
      @engine.policies.get[0].uuid.should == new_policy.uuid

      # Now we do a checkin for our node
      # This should trigger a policy binding because of a match to the policy rules tag and the node's tag
      @engine.mk_checkin($node_uuid, "idle").should == {"command_name"=>:acknowledge, "command_param"=>{}}

      # We should now have a binding for our node
      @engine.get_active_models.count.should == 1
      @engine.get_active_models[0].node_uuid.should == $node_uuid
      @engine.get_active_models[0].uuid.should_not == new_policy.uuid
    end
  end

end
