
require "project_razor"
require "rspec"
require "net/http"
require "json"




describe "ProjectRazor::Slice::Model" do

  describe ".RESTful Interface" do

    before(:all) do
      @data = ProjectRazor::Data.instance
      @data.check_init
      @config = ProjectRazor.config
      @data.delete_all_objects(:model)
    end

    after(:all) do
      @data.delete_all_objects(:model)
    end

    it "should be able to create a new Model from REST" do
      #uri = URI "http://127.0.0.1:#{@config.api_port}/razor/api/new_model"
      #
      #model_template = "test_tag_rule_web"
      #model_label = "testtag"
      #model_image_uuid = ""
      #model_req_metadata_hash = {}
      #
      #
      #json_hash = {:template => model_template,
      #             :label => model_label,
      #             :image_uuid => model_image_uuid,
      #             :req_metadata_hash => model_req_metadata_hash
      #              }
      #
      #json_string = JSON.generate(json_hash)
      #res = Net::HTTP.post_form(uri, 'json_hash' => json_string)
      #res.class.should == Net::HTTPCreated
      #response_hash = JSON.parse(res.body)
      #p response_hash
    end

  end

end
