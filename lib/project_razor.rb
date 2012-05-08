# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved

$razor_root = File.dirname(__FILE__).sub(/\/lib$/,"")
$config_server_path = "#{$razor_root}/conf/razor_server.conf"
$img_svc_path = "#{$razor_root}/image"
$logging_path = "#{$razor_root}/log/project_razor.log"
$temp_path = "#{$razor_root}/tmp"


#puts "Razor root: #{$razor_root}"
#puts "Logging path: #{$logging_path}"


require "project_razor/object"
require "project_razor/filtering"
require "project_razor/utility"
require "project_razor/logging"

require "project_razor/data"
require "project_razor/config"
require "project_razor/node"
require "project_razor/policy"
require "project_razor/engine"
require "project_razor/slice"
require "project_razor/persist"
require "project_razor/model"
require "project_razor/tagging"
require "project_razor/policies"
require "project_razor/image_service"
require "project_razor/power_control"
require "project_razor/broker"


$data = ProjectRazor::Data.new

# Root ProjectRazor namespace
# @author Nicholas Weaver
module ProjectRazor

end