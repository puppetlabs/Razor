require 'spec_helper'
require 'project_razor/slice/model'

describe ProjectRazor::Slice::Model do
  subject('slice') { ProjectRazor::Slice::Model.new([]) }

  # This checks for a bug found after pull request #437 was merged, where a
  # class that was not a classic object was added under the namespace.
  # Because we meta-program everything, this caused an error class to be
  # assumed to be a real broker plugin.  This ensures that doesn't sneak
  # in again.
  it "should be able to fetch all child template objects" do
    templates = slice.get_child_templates(ProjectRazor::ModelTemplate)
    templates.should_not be_empty
    templates.each {|t| t.should be_a ProjectRazor::ModelTemplate::Base }
  end
end
