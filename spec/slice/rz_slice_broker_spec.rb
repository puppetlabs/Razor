# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
## Copyright © 2012 EMC Corporation, All Rights Reserved

require "project_razor"
require "rspec"
require "net/http"
require "json"


describe "ProjectRazor::Slice::Broker" do

  describe ".RESTful Interface" do

    before(:all) do
      @data = ProjectRazor::Data.new
      @config = @data.config
      @data.delete_all_objects(:broker)
    end

    after(:all) do
      @data.delete_all_objects(:broker)
    end

    it "should be able to get broker plugins from REST" do
      # We create an array to test the different possible ways to get broker plugins
      uri_array = []
      uri_array << (URI "http://127.0.0.1:#{@config.api_port}/razor/api/broker/plugin")
      uri_array << (URI "http://127.0.0.1:#{@config.api_port}/razor/api/broker/plugins")
      uri_array << (URI "http://127.0.0.1:#{@config.api_port}/razor/api/broker/t")
      uri_array << (URI "http://127.0.0.1:#{@config.api_port}/razor/api/broker/get/plugin")
      uri_array << (URI "http://127.0.0.1:#{@config.api_port}/razor/api/broker/get/plugins")
      uri_array << (URI "http://127.0.0.1:#{@config.api_port}/razor/api/broker/get/t")
      uri_array.each do |uri|
        res = Net::HTTP.get(uri)
        res_hash = JSON.parse(res)
        brokers_plugins = res_hash['response']
        brokers_plugins.count.should > 0
        puppet_flag = false # We will just check for the puppet broker plugin
        brokers_plugins.each {|t| puppet_flag = true if t["@plugin"] == "puppet"}
        puppet_flag.should == true
      end
    end

    it "should be able to create broker target from REST using GET" do
      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/broker/add?plugin=puppet&name=RSPECPuppetGET&description=RSPECSystemInstanceGET&servers=rspecpuppet.example.org"
      res = Net::HTTP.get(uri)
      res_hash = JSON.parse(res)
      res_hash['result'].should == 'Ok'
      broker_response_array = res_hash['response']
      $broker_uuid_get = broker_response_array.first['@uuid']
      $broker_uuid_get.should_not == nil
    end

    it "should be able to create broker target from REST using POST" do
      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/broker/add"
      json_hash = {}
      json_hash["plugin"] = "puppet"
      json_hash["name"] = "RSPECPuppetPOST"
      json_hash["description"] = "RSPECSystemInstancePOST "
      json_hash["servers"] = ["rspecpuppet.example.org"]
      json_string = JSON.generate(json_hash)
      res = Net::HTTP.post_form(uri, 'json_hash' => json_string)
      res_hash = JSON.parse(res.body)
      res_hash['result'].should == 'Ok'
      broker_response_array = res_hash['response']
      $broker_uuid_post = broker_response_array.first['@uuid']
      $broker_uuid_post.should_not == nil
    end

    it "should be able to list all brokers targets from REST" do
      # We create an array to test the different possible ways to get broker plugins
      uri_array = []
      uri_array << (URI "http://127.0.0.1:#{@config.api_port}/razor/api/broker")
      uri_array << (URI "http://127.0.0.1:#{@config.api_port}/razor/api/broker/get")
      uri_array.each do |uri|
        res = Net::HTTP.get(uri)
        res_hash = JSON.parse(res)
        brokers_plugins = res_hash['response']
        brokers_plugins.count.should == 2
      end
    end

    it "should be able to find specific broker targets by UUID from REST" do
      # We create an array to test the different possible ways to get broker plugins
      uri_array = []
      uri_array << (URI "http://127.0.0.1:#{@config.api_port}/razor/api/broker/#{$broker_uuid_get}")
      uri_array << (URI "http://127.0.0.1:#{@config.api_port}/razor/api/broker/get/#{$broker_uuid_get}")
      uri_array.each do |uri|
        res = Net::HTTP.get(uri)
        res_hash = JSON.parse(res)
        broker_response_array = res_hash['response']
        broker_response_array.count.should == 1
        broker_response_array.first['@uuid'].should == $broker_uuid_get
      end
    end

    it "should be able to find specific broker targets by attribute from REST" do
      uri_array = []
      uri_array << (URI "http://127.0.0.1:#{@config.api_port}/razor/api/broker/get?name=regex:GET")
      uri_array << (URI "http://127.0.0.1:#{@config.api_port}/razor/api/broker?name=regex:GET")
      uri_array.each do |uri|
        res = Net::HTTP.get(uri)
        res_hash = JSON.parse(res)
        res_hash['result'].should == 'Ok'
        broker_response_array = res_hash['response']
        broker = broker_response_array.first
        broker['@uuid'].should == $broker_uuid_get
      end

      uri_array = []
      uri_array << (URI "http://127.0.0.1:#{@config.api_port}/razor/api/broker/get?name=RSPECPuppetPOST")
      uri_array.each do |uri|
        res = Net::HTTP.get(uri)
        res_hash = JSON.parse(res)
        res_hash['result'].should == 'Ok'
        broker_response_array = res_hash['response']
        broker = broker_response_array.first
        broker['@uuid'].should == $broker_uuid_post
      end
    end

    it "should be able to delete specific broker targets from REST" do
      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/broker/remove/#{$broker_uuid_get}"
      res = Net::HTTP.get(uri)
      res_hash = JSON.parse(res)
      res_hash['result'].should == 'Ok'

      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/broker/#{$broker_uuid_get}"
      res = Net::HTTP.get(uri)
      res_hash = JSON.parse(res)
      res_hash['errcode'].should_not == 0

      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/broker/remove/#{$broker_uuid_post}"
      res = Net::HTTP.get(uri)
      res_hash = JSON.parse(res)
      res_hash['result'].should == 'Ok'

      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/broker/#{$broker_uuid_post}"
      res = Net::HTTP.get(uri)
      res_hash = JSON.parse(res)
      res_hash['errcode'].should_not == 0

    end

    it "should be able to delete all broker targets from REST" do
      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/broker/add"
      json_hash = {}
      json_hash["plugin"] = "puppet"
      json_hash["description"] = "RSPECSystemInstancePOST "
      json_hash["servers"] = ["rspecpuppet.example.org"]
      (1..10).each do |x|
        json_hash["name"] = "RSPECPuppetPOST#{x}"
        json_string = JSON.generate(json_hash)
        res = Net::HTTP.post_form(uri, 'json_hash' => json_string)
        res_hash = JSON.parse(res.body)
        res_hash['result'].should == 'Ok'
        broker_response_array = res_hash['response']
        $broker_uuid_post = broker_response_array.first['@uuid']
        $broker_uuid_post.should_not == nil
      end

      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/broker"
      res = Net::HTTP.get(uri)
      res_hash = JSON.parse(res)
      brokers_get = res_hash['response']
      brokers_get.count.should == 10

      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/broker/remove/all"
      res = Net::HTTP.get(uri)
      res_hash = JSON.parse(res)
      res_hash['errcode'].should == 0

      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/broker"
      res = Net::HTTP.get(uri)
      res_hash = JSON.parse(res)
      brokers_get = res_hash['response']
      brokers_get.count.should == 0
    end
  end
end