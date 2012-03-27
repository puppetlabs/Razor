# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
## Copyright © 2012 EMC Corporation, All Rights Reserved

require "project_razor"
require "rspec"
require "net/http"
require "json"

describe "ProjectRazor::Slice::Tag" do

  describe ".RESTful Interface" do

    before(:all) do
      @data = ProjectRazor::Data.new
      @config = @data.config
      @data.delete_all_objects(:tag)
      @data.delete_all_objects(:node)
      @uuid = "TEST#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}"
      @node_uuid = "TEST#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}"
    end

    after(:all) do
      @data.delete_all_objects(:tag)
      @data.delete_all_objects(:node)
    end

    it "should be able to create a new empty tag rule from REST" do
      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/tag/rule/add"

      name = "test_tag_rule"
      tag = "RSPEC"

      json_hash = {}
      json_hash["@uuid"] = @uuid
      json_hash["@name"] = name
      json_hash["@tag"] = tag
      json_hash["@tag_matchers"] = []

      json_string = JSON.generate(json_hash)
      res = Net::HTTP.post_form(uri, 'json_hash' => json_string)
      response_hash = JSON.parse(res.body)

      response_hash['errcode'].should == 0
      response_hash['response'][0]['@name'].should == name
      response_hash['response'][0]['@tag'].should == tag
    end

    it "should be able to get one tag rule from REST" do
      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/tag/rule/#{@uuid}"
      res = Net::HTTP.get(uri)
      res_hash = JSON.parse(res)
      res_hash['response']['@uuid'].should == @uuid
    end


    it "should be able to create a tag matchers for a tag rule from REST" do

      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/tag/rule/#{@uuid}"
      res = Net::HTTP.get(uri)
      res_hash = JSON.parse(res)
      res_hash['response']['@uuid'].should == @uuid
      tag_rule = ProjectRazor::Tagging::TagRule.new(res_hash['response'])
      tag_rule.uuid.should == @uuid

      tag_rule.tag_matchers.count.should == 0

      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/tag/matcher/add/#{@uuid}"
      json_hash = {}
      json_hash["@key"] = "hostname"
      json_hash["@value"] = "nick01"
      json_hash["@compare"] = "equal"
      json_hash["@inverse"] = "false"
      json_string = JSON.generate(json_hash)
      res = Net::HTTP.post_form(uri, 'json_hash' => json_string)
      response_hash = JSON.parse(res.body)
      tag_rule = ProjectRazor::Tagging::TagRule.new(response_hash['response'])

      tag_rule.uuid.should == @uuid
      tag_rule.tag_matchers.count.should == 1
      tag_rule.tag_matchers[0].class.should == ProjectRazor::Tagging::TagMatcher
      tag_rule.tag_matchers[0].key.should == "hostname"
      tag_rule.tag_matchers[0].value.should == "nick01"
      tag_rule.tag_matchers[0].compare.should == "equal"
      tag_rule.tag_matchers[0].inverse.should == "false"

      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/tag/matcher/add/#{@uuid}"
      json_hash = {}
      json_hash["@key"] = "ip_address"
      json_hash["@value"] = 'regex:^192.168.1.1[0-9][0-9]$'
      json_hash["@compare"] = "like"
      json_hash["@inverse"] = "true"
      json_string = JSON.generate(json_hash)
      res = Net::HTTP.post_form(uri, 'json_hash' => json_string)
      response_hash = JSON.parse(res.body)
      tag_rule = ProjectRazor::Tagging::TagRule.new(response_hash['response'])

      tag_rule.uuid.should == @uuid
      tag_rule.tag_matchers.count.should == 2
      tag_rule.tag_matchers[1].class.should == ProjectRazor::Tagging::TagMatcher
      tag_rule.tag_matchers[1].key.should == "ip_address"
      tag_rule.tag_matchers[1].value.should == 'regex:^192.168.1.1[0-9][0-9]$'
      tag_rule.tag_matchers[1].compare.should == "like"
      tag_rule.tag_matchers[1].inverse.should == "true"
    end

    it "should be able to delete a tag matcher for a tag rule from REST" do

      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/tag/rule/#{@uuid}"
      res = Net::HTTP.get(uri)
      res_hash = JSON.parse(res)
      res_hash['response']['@uuid'].should == @uuid
      tag_rule = ProjectRazor::Tagging::TagRule.new(res_hash['response'])
      tag_rule.uuid.should == @uuid

      tag_rule.tag_matchers.count.should == 2

      tag_matcher = tag_rule.tag_matchers[0]
      tag_matcher.class.should == ProjectRazor::Tagging::TagMatcher

      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/tag/matcher/remove/#{@uuid}/#{tag_matcher.uuid}"
      res = Net::HTTP.get(uri)
      res_hash = JSON.parse(res)
      tag_rule = ProjectRazor::Tagging::TagRule.new(res_hash['response'])
      tag_rule.uuid.should == @uuid
      tag_rule.tag_matchers.count.should == 1
      tag_rule.tag_matchers[0].class.should == ProjectRazor::Tagging::TagMatcher
      tag_rule.tag_matchers[0].uuid.should_not == tag_matcher.uuid


    end




    it "should be able to delete a tag rule from REST" do
      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/tag/rule/#{@uuid}"
      res = Net::HTTP.get(uri)
      res_hash = JSON.parse(res)
      res_hash['response']['@uuid'].should == @uuid

      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/tag/rule/remove/#{@uuid}"
      res = Net::HTTP.get(uri)
      res_hash = JSON.parse(res)
      res_hash['errcode'].should == 0

      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/tag/rule/#{@uuid}"
      res = Net::HTTP.get(uri)
      res_hash = JSON.parse(res)
      res_hash['response'].should == "TagRuleNotFound"
    end




    it "should be able to get all tag rules from REST" do
      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/tag/rule/add"

      (1..10).each do
      |x|
        name = "test_tag_rule#{x}"
        tag = "RSPEC"

        json_hash = {}
        json_hash["@name"] = name
        json_hash["@tag"] = tag
        json_hash["@tag_matchers"] = []

        json_string = JSON.generate(json_hash)
        res = Net::HTTP.post_form(uri, 'json_hash' => json_string)
        response_hash = JSON.parse(res.body)

        response_hash['errcode'].should == 0
        response_hash['response']['@name'].should == name
        response_hash['response']['@tag'].should == tag
      end

      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/tag/rule"
      res = Net::HTTP.get(uri)
      res_hash = JSON.parse(res)
      tag_rules = res_hash['response']
      tag_rules.count.should == 10
    end



    it "should be able to get all tag rules that match attributes from REST" do
      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/tag/rule?@name=regex:test_tag_rule[3-5]"
      res = Net::HTTP.get(uri)
      res_hash = JSON.parse(res)
      tag_rules = res_hash['response']
      p res_hash



      tag_rules.count.should == 3
      tag_rules.each do
        |tag_r|
        (tag_r['@name'] == "test_tag_rule3" ||
            tag_r['@name'] == "test_tag_rule4" ||
            tag_r['@name'] == "test_tag_rule5").should == true
      end

    end

    it "should successfully tag and get tags back from node object (Complex test)"  do


      #### We create an empty tag rule with the tag: RSPEC_ONE
      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/tag/rule/add"
      name = "live_test_tag_rule1"
      tag = "RSPEC_ONE"
      json_hash = {}
      json_hash["@name"] = name
      json_hash["@tag"] = tag
      json_hash["@tag_matchers"] = []
      json_string = JSON.generate(json_hash)
      res = Net::HTTP.post_form(uri, 'json_hash' => json_string)
      response_hash = JSON.parse(res.body)
      live_tag_rule_uuid1 = response_hash['response']['@uuid']


      # We add two tag matchers to it
      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/tag/matcher/add/#{live_tag_rule_uuid1}"
      json_hash = {}
      json_hash["@key"] = "hostname"
      json_hash["@value"] = "rspechost"
      json_hash["@compare"] = "like"
      json_hash["@inverse"] = "false"
      json_string = JSON.generate(json_hash)
      res = Net::HTTP.post_form(uri, 'json_hash' => json_string)
      json_hash = {}
      json_hash["@key"] = "ip address"
      json_hash["@value"] = '192\.168\.13\.1[6][0-9]'
      json_hash["@compare"] = "like"
      json_hash["@inverse"] = "false"
      json_string = JSON.generate(json_hash)
      Net::HTTP.post_form(uri, 'json_hash' => json_string)


      #### We create an empty tag rule with the tag: RSPEC_TWO
      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/tag/rule/add"
      name = "live_test_tag_rule2"
      tag = "RSPEC_TWO"
      json_hash = {}
      json_hash["@name"] = name
      json_hash["@tag"] = tag
      json_hash["@tag_matchers"] = []
      json_string = JSON.generate(json_hash)
      res = Net::HTTP.post_form(uri, 'json_hash' => json_string)
      response_hash = JSON.parse(res.body)
      live_tag_rule_uuid2 = response_hash['response']['@uuid']


      # We add one tag matchers to it
      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/tag/matcher/add/#{live_tag_rule_uuid2}"
      json_hash = {}
      json_hash["@key"] = "secure"
      json_hash["@value"] = 'true'
      json_hash["@compare"] = "like"
      json_hash["@inverse"] = "true"
      json_string = JSON.generate(json_hash)
      Net::HTTP.post_form(uri, 'json_hash' => json_string)


      #### We register first node with specific attributes
      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/node/register" # root URI for node slice actions
      state = "idle"
      json_hash = {}
      json_hash["@uuid"] = "TEST#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}"
      json_hash["@last_state"] = state
      json_hash["@attributes_hash"] = {"hostname" => "rspechost123",
                                       "ip address" => "192.168.13.165",
                                       "building" => "A",
                                       "domainname" => "test-dev",
                                       "secure" => "true",
                                       "junk" => "value"}
      json_string = JSON.generate(json_hash)
      res = Net::HTTP.post_form(uri, 'json_hash' => json_string)
      response_hash = JSON.parse(res.body)
      response_hash['errcode'].should == 0
      node = ProjectRazor::Node.new(response_hash['response'])
      node.tags.should == %W(RSPEC_ONE) # Only should be tagged with the first tag

      #### We register second node with specific attributes
      state = "idle"
      json_hash = {}
      json_hash["@uuid"] = "TEST#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}"
      json_hash["@last_state"] = state
      json_hash["@attributes_hash"] = {"hostname" => "rspechost123",
                                       "ip address" => "192.168.13.165",
                                       "building" => "A",
                                       "domainname" => "test-dev",
                                       "secure" => "false",
                                       "junk" => "value"}
      json_string = JSON.generate(json_hash)
      res = Net::HTTP.post_form(uri, 'json_hash' => json_string)
      response_hash = JSON.parse(res.body)
      response_hash['errcode'].should == 0
      node = ProjectRazor::Node.new(response_hash['response'])
      node.tags.should == %W(RSPEC_ONE RSPEC_TWO) # Should be tagged with both tags

      #### We register third node with specific attributes
      state = "idle"
      json_hash = {}
      json_hash["@uuid"] = "TEST#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}#{rand(9)}"
      json_hash["@last_state"] = state
      json_hash["@attributes_hash"] = {"hostname" => "rspechost123",
                                       "ip address" => "192.168.13.155",
                                       "building" => "A",
                                       "domainname" => "test-dev",
                                       "secure" => "false",
                                       "junk" => "value"}
      json_string = JSON.generate(json_hash)
      res = Net::HTTP.post_form(uri, 'json_hash' => json_string)
      response_hash = JSON.parse(res.body)
      response_hash['errcode'].should == 0
      node = ProjectRazor::Node.new(response_hash['response'])
      node.tags.should == %W(RSPEC_TWO) # Only should be tagged with the third tag
    end

  end

end