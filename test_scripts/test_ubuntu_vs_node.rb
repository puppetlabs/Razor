#!/usr/bin/env ruby

$lib_path = File.dirname(File.expand_path(__FILE__)).sub(/\/test_scripts$/,"/lib")
$LOAD_PATH.unshift($lib_path)
require "project_razor"
require "colored"
require "net/http"

puts "\nThis script is for doing the following:".green
puts "\t 1) Creating a tag rule and tag matcher"
#puts "\t 2) Creating policy rule for matching tag above with LinuxDeploy model"
#puts "\n\n"
#puts "This will cause any node that gets tagged to be rebooted by the LinuxDeploy model applied by the rule"
puts "\n"
puts "Once bound, you have to ru-run rspec tests to remove the bound policy".red
puts "\n"
puts "Make sure your checkin forced actions are clear for the node, these override anything above.".red
puts "\n\n"

puts "** Please enter the UUID of the node to work with:"
node_uuid = gets.strip

data = ProjectRazor::Data.new
engine = ProjectRazor::Engine.instance
config  = data.config

data.delete_all_objects(:tag)
#data.delete_all_objects(:policy_rule)
data.delete_all_objects(:bound_policy)

node = data.fetch_object_by_uuid(:node, node_uuid)
if node


  puts "...creating a tag rule"
  #### We create an empty tag rule with the tag: TEST_TAG
  uri = URI "http://127.0.0.1:#{config.api_port}/razor/api/tag/rule/add"
  name = "live_test_tag_rule_for_engine"
  tag = "test"
  json_hash = {}
  json_hash["@name"] = name
  json_hash["@tag"] = tag
  json_hash["@tag_matchers"] = []
  json_string = JSON.generate(json_hash)
  res = Net::HTTP.post_form(uri, 'json_hash' => json_string)
  response_hash = JSON.parse(res.body)
  live_tag_rule_uuid = response_hash['response']['@uuid']
  sleep 1

  puts "...adding a tag matcher to tag rule to match 'hostname' => '#{node.attributes_hash['hostname']}'"
  # We add one tag matchers to it
  uri = URI "http://127.0.0.1:#{config.api_port}/razor/api/tag/matcher/add/#{live_tag_rule_uuid}"
  json_hash = {}
  json_hash["@key"] = "hostname"
  json_hash["@value"] = node.attributes_hash['hostname'] # Match to our hostname
  json_hash["@compare"] = "equal"
  json_hash["@inverse"] = "false"
  json_string = JSON.generate(json_hash)
  Net::HTTP.post_form(uri, 'json_hash' => json_string)
  sleep 1

  #puts "...creating policy rule for TEST_TAG to bind LinuxDeploy policy"
  ## Create a new policy rule
  #new_policy_rule = ProjectRazor::Policy::LinuxDeploy.new({})
  #new_policy_rule.name = "Rule for node:#{node.uuid}"
  #new_policy_rule.kernel_path = "test"
  #new_policy_rule.model = ProjectRazor::Model::Base.new({})
  #new_policy_rule.tags << "TEST_TAG"



  # We add our policy rule
  #engine.policy_rules.add(new_policy_rule)


  puts "Next check in the policy will be bound, the following checkin the model will be called."
  sleep 4

else
  puts "Cannot find Node:#{node_uuid} - please make sure it is checking into Razor first"


end



puts "Node UUID: #{node_uuid}"





