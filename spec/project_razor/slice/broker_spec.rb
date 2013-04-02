require 'spec_helper'
require 'project_razor/slice/broker'

describe ProjectRazor::Slice::Broker do
  subject('slice') { ProjectRazor::Slice::Broker.new([]) }

  # This checks for a bug found after pull request #437 was merged, where a
  # class that was not a classic object was added under the namespace.
  # Because we meta-program everything, this caused an error class to be
  # assumed to be a real broker plugin.  This ensures that doesn't sneak
  # in again.
  it "should be able to fetch all child template objects" do
    templates = slice.get_child_templates(ProjectRazor::BrokerPlugin)
    templates.should_not be_empty
    templates.each {|t| t.should be_a ProjectRazor::BrokerPlugin::Base }
  end
end
