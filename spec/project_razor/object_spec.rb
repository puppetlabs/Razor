require 'spec_helper'
require 'project_razor/object'

describe ProjectRazor::Object do
  # REVISIT: all of these should test the method, not just that it exists.
  it { should respond_to :uuid }
  it { should respond_to :version }
  it { should respond_to :classname }
  it { should respond_to :_persist_ctrl }
  it { should respond_to :_namespace }
  it { should respond_to :is_template }
  it { should respond_to :noun }
end
