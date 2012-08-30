
require "project_razor"
require "rspec"
require "net/http"
require "json"

describe "ProjectRazor::Slice::Bmc" do

  # {"00:15:17:FA:E0:36"=>"192.168.2.51", "00:15:17:FA:DE:66"=>"192.168.2.52",
  #  "00:15:17:FA:7B:0A"=>"192.168.2.53"}
  describe ".RESTful Interface" do

    before(:all) do
      @data = ProjectRazor::Data.instance
      @data.check_init
      @config = @data.config
      @data.delete_all_objects(:bmc)
      @mac = ["00:15:17:FA:E0:36", "00:15:17:FA:DE:66"]
      @ip = ["192.168.2.51", "192.168.2.52"]
    end

    after(:all) do
      @data.delete_all_objects(:bmc)
    end

    it "should be able to register a bmc object from REST" do
      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/bmc/register"

      json_hash = {}
      json_hash["mac_address"] = @mac[0]
      json_hash["ip_address"] = @ip[0]

      json_string = JSON.generate(json_hash)
      res = Net::HTTP.post_form(uri, 'json_hash' => json_string)
      response_hash = JSON.parse(res.body)

      response_hash['errcode'].should == 0
      bmc_nodes = response_hash['response']
      bmc_nodes['@mac'].should == @mac[0]
      bmc_nodes['@ip'].should == @ip[0]
    end

    it "should be able to get one bmc 'node' from REST" do
      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/bmc?@mac=#{@mac[0]}"
      res = Net::HTTP.get(uri)
      response_hash = JSON.parse(res)
      bmc_nodes = response_hash['response']
      bmc_nodes[0]['@mac'].should == @mac[0]
      bmc_nodes[0]['@ip'].should == @ip[0]
    end

    it "should be able to get all bmc 'nodes' from REST" do
      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/bmc/register"

      len = @mac.length
      # for all indexes from 0 to the len-1, loop and register each BMC
      (0...len).each do
      |x|

        json_hash = {}
        json_hash["mac_address"] = @mac[x]
        json_hash["ip_address"] = @ip[x]

        json_string = JSON.generate(json_hash)
        res = Net::HTTP.post_form(uri, 'json_hash' => json_string)
        response_hash = JSON.parse(res.body)

        response_hash['errcode'].should == 0
        bmc_nodes = response_hash['response']
        bmc_nodes['@mac'].should == @mac[x]
        bmc_nodes['@ip'].should == @ip[x]
      end

      # now get all of them, and test the response length (should be the same as the
      # @mac array length, determined above)
      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/bmc"
      res = Net::HTTP.get(uri)
      response_hash = JSON.parse(res)
      bmc_nodes = response_hash['response']
      bmc_nodes.count.should == len
    end

    it "should be able to get all bmc 'nodes' that match attributes from REST" do
      uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/bmc?@ip=regex:192.168.2.5[1-2]"
      res = Net::HTTP.get(uri)
      response_hash = JSON.parse(res)
      bmc_nodes = response_hash['response']
      bmc_nodes.count.should == 2
      # TODO - there is no option to get specific nodes with the BMC slice
    end

  end

end
