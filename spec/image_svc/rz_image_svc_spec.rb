## EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
## Copyright © 2012 EMC Corporation, All Rights Reserved
#
#require "project_razor"
#require "rspec"
#
#describe ProjectRazor::ImageService do
#
#  before(:all) do
#    @data = ProjectRazor::Data.new
#    @config = @data.config
#  end
#
#
#  describe ".Microkernel" do
#    it "should do something" do
#      new_mk = ProjectRazor::ImageService::MicroKernel.new({})
#      resp = new_mk.add("#{$razor_root}/rz_mk_dev-image.0.2.1.0.iso", @config.image_svc_path)
#      p resp
#      p new_mk
#
#      v = new_mk.verify(@config.image_svc_path)
#      puts "Verify: #{v}"
#    end
#
#  end
#end