require "project_razor"
require "rspec"
require "net/http"
require "json"

describe "ProjectRazor::Slice::Broker" do

  describe ".RESTful Interface" do

    before(:each) do
      @data = ProjectRazor::Data.instance
      @data.check_init
      @config = @data.config
      @data.delete_all_objects(:broker)
    end

    after(:each) do
      @data.delete_all_objects(:broker)
    end

    def razor_uri(path, json_hash = nil)
      return URI("http://127.0.0.1:#{@config.api_port}/#{path.sub(%r{^/}, '')}") unless json_hash
      json_hash_str = URI.encode(JSON.generate(json_hash))
      URI("http://127.0.0.1:#{@config.api_port}/#{path.sub(%r{^/}, '')}?json_hash=#{json_hash_str}")
    end

    def http_get(path)
      response = Net::HTTP.get(razor_uri(path))
      JSON.parse(response)
    end

    def http_post(path, hash)
      uri = razor_uri(path)
      response = Net::HTTP.post_form(uri, 'json_hash' => JSON.generate(hash))
      JSON.parse(response.body)
    end

    def http_put(path, hash)
      uri = razor_uri(path, hash)
      Net::HTTP.start(uri.host, uri.port) do |http|
        response = http.send_request('PUT', uri.request_uri)
        JSON.parse(response.body)
      end
    end

    def create_broker_via_rest(hash)
      http_post("/razor/api/broker/add", hash)
    end

    let(:json_hash) do
      {
        "plugin"      => "puppet",
        "name"        => "puppet_test",
        "description" => "puppet_test_description",
        "req_metadata_hash" => {
          "server"          => "puppet.example.com",
          "broker_version"  => "2.0.9"
        }
      }
    end

    [ "/razor/api/broker/plugins", "/razor/api/broker/get/plugins" ].each do |path|
      it "GET #{path} lists all broker plugins" do
        res_hash = http_get(path)
        brokers_plugins = res_hash['response']
        brokers_plugins.count.should > 0
        puppet_flag = false # We will just check for the puppet broker plugin
        brokers_plugins.each {|t| puppet_flag = true if t["@plugin"] == "puppet"}
        puppet_flag.should == true
      end
    end

    context "with no broker targets" do

      it "should not be able to create broker target from REST using GET" do
        # pending "Not a published API action"
        lcl_hash = {"plugin" => "puppet", "name" => "RSPECPuppetGET",
          "description" => "RSPECSystemInstanceGET", "req_metadata_hash" => {
            "server" => "rspecpuppet.example.org", "broker_version" => ""}}
        uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/broker/add?" +
          "json_hash=#{URI.encode(JSON.generate(lcl_hash))}"
        res = Net::HTTP.get(uri)

        res_hash = JSON.parse(res)
        res_hash['result'].should_not == "Created"
      end

      it "POST /razor/api/broker/add creates a broker target" do
        res_hash = http_post("/razor/api/broker/add", json_hash)
        res_hash['result'].should == "Created"
        broker = res_hash['response'].first
        broker['@name'].should eq("puppet_test")
        broker['@user_description'].should eq("puppet_test_description")
        broker['@server'].should eq("puppet.example.com")
        broker['@broker_version'].should eq("2.0.9")
      end

    end

    context "with one broker target" do

      before do
        res_hash = create_broker_via_rest(json_hash)
        @broker = res_hash['response'].first
      end

      [ "/razor/api/broker", "/razor/api/broker/get" ].each do |path|
        it "GET #{path} lists all brokers targets" do
          res_hash = http_get(path)
          brokers_plugins = res_hash['response']
          brokers_plugins.count.should == 1
          brokers_plugins.first['@uuid'].should eq(@broker['@uuid'])
        end
      end

      [ "/razor/api/broker", "/razor/api/broker/get" ].each do |path|
        it "GET #{path}/<uuid> finds the specific broker target" do
          broker_uuid = @broker['@uuid']
          res_hash = http_get("#{path}/#{broker_uuid}")
          broker_response_array = res_hash['response']
          broker_response_array.count.should == 1
          broker_response_array.first['@uuid'].should == broker_uuid
        end

        it "GET #{path}?name=regex:<text> finds the broker target by attribute" do
          res_hash = http_get("#{path}?name=regex:puppet")
          res_hash['result'].should == "Ok"
          broker_response_array = res_hash['response']
          broker = broker_response_array.first
          broker['@uuid'].should == @broker['@uuid']
        end

        it "GET /#{path}?name=<full_text> finds the broker target by attribute" do
          res_hash = http_get("#{path}?name=puppet_test")
          res_hash['result'].should == "Ok"
          broker_response_array = res_hash['response']
          broker = broker_response_array.first
          broker['@uuid'].should == @broker['@uuid']
        end

        it "PUT /#{path}/#{@uuid}?json_hash=<json_str> should allow update of broker using default server/version" do
          # pending "Not a published API action"
          lcl_hash = {"plugin" => "puppet", "name" => "RSPECPuppetBrokerPUT1",
            "description" => "RSPECPuppetBrokerInstancePUT1", "req_metadata_hash" => {
              "server" => "", "broker_version" => ""}}
          res = http_put("/razor/api/broker/update/#{@broker['@uuid']}", lcl_hash)
          res['result'].should == "Updated"
        end

        it "PUT /#{path}/#{@uuid}?json_hash=<json_str> should allow update of broker using valid server/version" do
          # pending "Not a published API action"
          lcl_hash = {"plugin" => "puppet", "name" => "RSPECPuppetBrokerPUT1",
            "description" => "RSPECPuppetBrokerInstancePUT1", "req_metadata_hash" => {
              "server" => "puppet-local.localdomain.net", "broker_version" => "3.0.1_rc1"}}
          res = http_put("/razor/api/broker/update/#{@broker['@uuid']}", lcl_hash)
          res['result'].should == "Updated"
          broker = res['response'].first
          broker['@server'].should == "puppet-local.localdomain.net"
          broker['@broker_version'].should == "3.0.1_rc1"
        end

        it "PUT /#{path}/#{@uuid}?json_hash=<json_str> should fail to update a broker with an invalid hostname" do
          # pending "Not a published API action"
          lcl_hash = {"plugin" => "puppet", "name" => "RSPECPuppetBrokerPUT1",
            "description" => "RSPECPuppetBrokerInstancePUT1", "req_metadata_hash" => {
              "server" => "---invalid-hostname---", "broker_version" => ""}}
          res = http_put("/razor/api/broker/update/#{@broker['@uuid']}", lcl_hash)
          res['result'].should_not == "Updated"
          res['http_err_code'].should == 400
          res['err_class'].should == "ProjectRazor::Error::Slice::InvalidBrokerMetadata"
        end

        it "PUT /#{path}/#{@uuid}?json_hash=<json_str> should fail to update a broker with an invalid version" do
          # pending "Not a published API action"
          lcl_hash = {"plugin" => "puppet", "name" => "RSPECPuppetBrokerPUT1",
            "description" => "RSPECPuppetBrokerInstancePUT1", "req_metadata_hash" => {
              "server" => "", "broker_version" => "this_is_not_a_valid_broker_version"}}
          res = http_put("/razor/api/broker/update/#{@broker['@uuid']}", lcl_hash)
          res['result'].should_not == "Updated"
          res['http_err_code'].should == 400
          res['err_class'].should == "ProjectRazor::Error::Slice::InvalidBrokerMetadata"
        end

      end

      it "GET /remove/api/broker/remove/<uuid> deletes specific broker target" do
        broker_uuid = @broker['@uuid']

        res_hash = http_get("/razor/api/broker/remove/#{broker_uuid}")
        res_hash['result'].should == "Removed"

        res_hash = http_get("/razor/api/broker/#{broker_uuid}")
        res_hash['errcode'].should_not == 0
      end

      it "DELETE /razor/api/broker/remove/all cannot delete all broker targets" do
        uri = razor_uri("/razor/api/broker/remove/all")
        http = Net::HTTP.start(uri.host, uri.port)
        res = http.send_request('DELETE', uri.request_uri)
        res.class.should == Net::HTTPMethodNotAllowed
        res_hash = JSON.parse(res.body)

        res_hash = http_get("/razor/api/broker")
        brokers_get = res_hash['response']
        brokers_get.count.should == 1
      end
    end
  end
end
