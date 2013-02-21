
require "project_razor"
require "rspec"
require "net/http"
require "json"




describe "ProjectRazor::Slice::Tag" do

  describe ".RESTful Interface" do

    before(:all) do
      @data = ProjectRazor::Data.instance
      @data.check_init
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
      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/tag"

      name = "test_tag_rule_web"
      tag = "testtag"

      json_hash = {}
      json_hash["@name"] = name
      json_hash["@tag"] = tag

      json_string = JSON.generate(json_hash)
      res = Net::HTTP.post_form(uri, 'json_hash' => json_string)
      res.class.should == Net::HTTPCreated
      response_hash = JSON.parse(res.body)
      response_hash['http_err_code'].should == 201
      $uuid01 = response_hash['response'][0]['@uuid']
      $tag_rule_uri01 = response_hash['response'][0]['@uri']

      uri = URI $tag_rule_uri01
      res = Net::HTTP.get(uri)
      res_hash = JSON.parse(res)
      res_hash['response'][0]['@name'].should == name
      res_hash['response'][0]['@tag'].should == tag

    end

    it "should be able to update a new tag rule from REST" do
      uri = URI $tag_rule_uri01
      res = Net::HTTP.get(uri)
      res_hash = JSON.parse(res)
      res_hash['response'].first['@uuid'].should == $uuid01
      tagrule_hash =  res_hash['response'].first
      tagrule_hash['@name'].should == "test_tag_rule_web"
      tagrule_hash['@tag'].should == "testtag"

      json_hash = {}
      json_hash["name"] = "changed"
      json_string = JSON.generate(json_hash)
      uri = URI $tag_rule_uri01
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Put.new(uri.request_uri)
      request.set_form_data('json_hash' => json_string)
      res = http.request(request)
      res.class.should == Net::HTTPAccepted
      response_hash = JSON.parse(res.body)
      tagrule_hash = response_hash['response'].first
      tagrule_hash['@name'].should == "changed"
      json_hash = {"name" => "newname", "tag" => "somethingelse"}
      json_string = JSON.generate(json_hash)
      request = Net::HTTP::Put.new(uri.request_uri)
      request.set_form_data('json_hash' => json_string)
      res = http.request(request)
      res.class.should == Net::HTTPAccepted
      response_hash = JSON.parse(res.body)
      tagrule_hash = response_hash['response'].first
      tagrule_hash['@name'].should == "newname"
      tagrule_hash['@tag'].should == "somethingelse"
    end

    it "should be able to create a tag matchers for a tag rule from REST" do

      uri = URI $tag_rule_uri01
      res = Net::HTTP.get(uri)
      res_hash = JSON.parse(res)
      res_hash['response'].first['@uuid'].should == $uuid01
      tag_rule = ProjectRazor::Tagging::TagRule.new(res_hash['response'].first)
      tag_rule.uuid.should == $uuid01
      tag_rule.tag_matchers.count.should == 0
      matcher_uri = "http://127.0.0.1:#{@config.api_port}/razor/api/tag/#{tag_rule.uuid}/matcher"

      uri = URI matcher_uri
      json_hash = {}
      json_hash["key"] = "hostname"
      json_hash["value"] = "nick01"
      json_hash["compare"] = "equal"
      json_hash["inverse"] = "false"
      json_string = JSON.generate(json_hash)
      res = Net::HTTP.post_form(uri, 'json_hash' => json_string)
      res.class.should == Net::HTTPCreated
      response_hash = JSON.parse(res.body)
      uri = URI response_hash['response'].first['@uri']
      res = Net::HTTP.get(uri)
      response_hash = JSON.parse(res)
      matcher = ProjectRazor::Tagging::TagMatcher.new(response_hash['response'].first, tag_rule.uuid)
      matcher.key.should == "hostname"
      matcher.value.should == "nick01"
      matcher.compare.should == "equal"
      matcher.inverse.should == "false"
      uri = URI matcher_uri
      json_hash["key"] = "ip_address"
      json_hash["value"] = 'regex:^192.168.1.1[0-9][0-9]$'
      json_hash["compare"] = "like"
      json_hash["inverse"] = "true"
      json_string = JSON.generate(json_hash)
      res = Net::HTTP.post_form(uri, 'json_hash' => json_string)
      res.class.should == Net::HTTPCreated
      response_hash = JSON.parse(res.body)
      uri = URI response_hash['response'].first['@uri']
      res = Net::HTTP.get(uri)
      response_hash = JSON.parse(res)
      matcher_hash = response_hash['response'].first
      matcher_hash['@key'].should == "ip_address"
      matcher_hash['@value'].should == 'regex:^192.168.1.1[0-9][0-9]$'
      matcher_hash['@compare'].should == "like"
      matcher_hash['@inverse'].should == "true"
    end

    it "should be able to update values for a tag matcher for a tag rule from REST" do
      uri = URI $tag_rule_uri01
      res = Net::HTTP.get(uri)
      res_hash = JSON.parse(res)
      res_hash['response'].first['@uuid'].should == $uuid01
      tagrule_hash =  res_hash['response'].first
      tagrule_hash['@tag_matchers'].count.should == 2
      matcher_hash = tagrule_hash['@tag_matchers'][0]
      $matcher_uuid01 = matcher_hash['@uuid']
      matcher_hash['@key'].should == "hostname"
      matcher_hash['@value'].should == "nick01"
      matcher_hash['@compare'].should == "equal"
      matcher_hash['@inverse'].should == "false"

      json_hash = {}
      json_hash["key"] = "changed"
      json_string = JSON.generate(json_hash)
      uri = URI matcher_hash['@uri']
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Put.new(uri.request_uri)
      request.set_form_data('json_hash' => json_string)
      res = http.request(request)
      res.class.should == Net::HTTPAccepted
      response_hash = JSON.parse(res.body)
      matcher_hash = response_hash['response'].first
      matcher_hash['@key'].should == "changed"
      json_hash = {}
      json_hash = {"value" => "newname", "compare" => "like", "inverse" => "true"}
      json_string = JSON.generate(json_hash)
      request = Net::HTTP::Put.new(uri.request_uri)
      request.set_form_data('json_hash' => json_string)
      res = http.request(request)
      res.class.should == Net::HTTPAccepted
      response_hash = JSON.parse(res.body)
      matcher_hash = response_hash['response'].first
      matcher_hash['@value'].should == "newname"
      matcher_hash['@compare'].should == "like"
      matcher_hash['@inverse'].should == "true"
    end

    it "should be able to delete a tag matcher for a tag rule from REST" do
      uri = URI $tag_rule_uri01
      res = Net::HTTP.get(uri)
      res_hash = JSON.parse(res)
      res_hash['response'].first['@uuid'].should == $uuid01
      tagrule_hash =  res_hash['response'].first
      tagrule_hash['@tag_matchers'].count.should == 2
      matcher_hash = tagrule_hash['@tag_matchers'][0]


      uri = URI matcher_hash['@uri']
      http = Net::HTTP.start(uri.host, uri.port)
      res = http.send_request('DELETE', uri.request_uri)
      res.class.should == Net::HTTPAccepted
      response_hash = JSON.parse(res.body)
      tagrule_hash = response_hash['response'].first
      tagrule_hash['@uuid'].should == $uuid01
      tagrule_hash['@tag_matchers'].count.should == 1
    end

    it "should be able to delete a tag rule from REST" do
      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/tag"
      res = Net::HTTP.get(uri)
      res_hash = JSON.parse(res)
      res_hash['response'].count.should == 1

      uri = URI $tag_rule_uri01
      http = Net::HTTP.start(uri.host, uri.port)
      res = http.send_request('DELETE', uri.request_uri)
      res.class.should == Net::HTTPAccepted
      response_hash = JSON.parse(res.body)

      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/tag"
      res = Net::HTTP.get(uri)
      res_hash = JSON.parse(res)
      res_hash['response'].count.should == 0
    end

    it "should be able to get all tag rules from REST" do
      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/tag/add"

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
        response_hash['response'].first['@name'].should == name
        response_hash['response'].first['@tag'].should == tag
      end

      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/tag"
      res = Net::HTTP.get(uri)
      res_hash = JSON.parse(res)
      tag_rules = res_hash['response']
      tag_rules.count.should == 10
    end

    it "should be able to get all tag rules that match attributes from REST" do
      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/tag?name=regex:test_tag_rule[3-5]"
      res = Net::HTTP.get(uri)
      res_hash = JSON.parse(res)
      tag_rules = res_hash['response']
      tag_rules.count.should == 3
    end

    it "should successfully tag and get tags back from node object (Complex test)"  do


      #### We create an empty tag rule with the tag: RSPEC_ONE
      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/tag"
      name = "live_test_tag_rule1"
      tag = "RSPEC_ONE"
      json_hash = {}
      json_hash["@name"] = name
      json_hash["@tag"] = tag
      json_hash["@tag_matchers"] = []
      json_string = JSON.generate(json_hash)
      res = Net::HTTP.post_form(uri, 'json_hash' => json_string)
      response_hash = JSON.parse(res.body)
      live_tag_rule_uuid1 = response_hash['response'].first['@uuid']


      # We add two tag matchers to it
      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/tag/#{live_tag_rule_uuid1}/matcher"
      json_hash = {}
      json_hash["tag_rule_uuid"] = live_tag_rule_uuid1
      json_hash["@key"] = "hostname"
      json_hash["@value"] = "rspechost"
      json_hash["@compare"] = "like"
      json_hash["@inverse"] = "false"
      json_string = JSON.generate(json_hash)
      res = Net::HTTP.post_form(uri, 'json_hash' => json_string)
      json_hash = {}
      json_hash["tag_rule_uuid"] = live_tag_rule_uuid1
      json_hash["@key"] = "ip address"
      json_hash["@value"] = '192\.168\.13\.1[6][0-9]'
      json_hash["@compare"] = "like"
      json_hash["@inverse"] = "false"
      json_string = JSON.generate(json_hash)
      Net::HTTP.post_form(uri, 'json_hash' => json_string)


      #### We create an empty tag rule with the tag: RSPEC_TWO
      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/tag"
      name = "live_test_tag_rule2"
      tag = "RSPEC_TWO"
      json_hash = {}
      json_hash["@name"] = name
      json_hash["@tag"] = tag
      json_hash["@tag_matchers"] = []
      json_string = JSON.generate(json_hash)
      res = Net::HTTP.post_form(uri, 'json_hash' => json_string)
      response_hash = JSON.parse(res.body)
      live_tag_rule_uuid2 = response_hash['response'].first['@uuid']


      # We add one tag matchers to it
      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/tag/#{live_tag_rule_uuid2}/matcher/"
      json_hash = {}
      json_hash["tag_rule_uuid"] = live_tag_rule_uuid2
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

    it "should not be able to delete all tag rules from REST" do
      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/tag/all"
      http = Net::HTTP.start(uri.host, uri.port)
      res = http.send_request('DELETE', uri.request_uri)
      res.class.should == Net::HTTPMethodNotAllowed
      response_hash = JSON.parse(res.body)

      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/tag"
      res = Net::HTTP.get(uri)
      res_hash = JSON.parse(res)
      res_hash['response'].count.should == 12
    end

  end

end
