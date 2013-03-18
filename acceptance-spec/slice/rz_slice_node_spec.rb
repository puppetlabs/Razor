
require "project_razor"
require "rspec"
require "net/http"
require "json"

describe "ProjectRazor::Slice::Node" do

  describe ".RESTful Interface" do

    before(:all) do
      @data = ProjectRazor::Data.instance
      @data.check_init
      @config = ProjectRazor.config

      @hw_id = "TEST#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}"
    end

    after(:all) do
      @data.delete_all_objects(:node)

    end

    it "Should be able to register a node by uuid from REST" do
      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/node/register" # root URI for node slice actions


      state = "idle"

      json_hash = {}
      json_hash["@uuid"] = @hw_id
      json_hash["@last_state"] = state
      json_hash["@attributes_hash"] = {"hostname" => "nick01.example.com",
                                       "ip_address" => "1.1.1.1"}

      json_string = JSON.generate(json_hash)
      res = Net::HTTP.post_form(uri, 'json_hash' => json_string)
      response_hash = JSON.parse(res.body)

      response_hash['errcode'].should == 0
      $node_uuid1 = response_hash['response']['@uuid']
    end


    it "Should be able to query a list of nodes from REST" do
      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/node"

      res = Net::HTTP.get(uri)
      response_hash = JSON.parse(res)

      response_hash['errcode'].should == 0
      nodes = response_hash['response']
      nodes.count.should > 0
      nodes.each do
        |node|
        node['@uuid'].should_not == nil
      end
    end

    it "Should be able to query a single node by uuid from REST" do
      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/node/#{$node_uuid1}"

      res = Net::HTTP.get(uri)
      response_hash = JSON.parse(res)

      response_hash['errcode'].should == 0
      nodes = response_hash['response']
      nodes.count.should == 1
      nodes.each do
      |node|
        node['@uuid'].should == $node_uuid1
      end
    end

    it "Should be able to checkin a node by uuid from REST and get back acknowledge" do
      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/node/checkin?uuid=#{@hw_id}&last_state=idle_error"

      res = Net::HTTP.get(uri)
      response_hash = JSON.parse(res)

      response_hash['errcode'].should == 0
      response_hash['response']['command_name'].should == "acknowledge"

      node = @data.fetch_object_by_uuid(:node, $node_uuid1)
      node.last_state.should == "idle_error"

    end

    it "Should be able to checkin a node by uuid from REST and get back register" do
      node = @data.fetch_object_by_uuid(:node, $node_uuid1)
      node.timestamp = 0 # force node register timeout to have been expired
      node.update_self
      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/node/checkin?uuid=#{@hw_id}&last_state=idle"

      res = Net::HTTP.get(uri)
      response_hash = JSON.parse(res)

      response_hash['errcode'].should == 0
      response_hash['response']['command_name'].should == "register"

      node.refresh_self
      node.last_state.should == "idle"
    end

  end
end
