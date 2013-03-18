require 'spec_helper'
require 'project_razor/slice/policy'
require 'project_razor/model/debian'

describe ProjectRazor::Slice::Policy do
  describe "razor policy add" do
    let('model') do
      model = ProjectRazor::ModelTemplate::Debian.new({})

      # @todo danielp 2013-03-18: for now, this is required to make us connect
      # to the database, because the code still depends on every consumer of
      # database services being aware of, and responsible for, the full
      # life-cycle of those connections.  This needs to change.
      ProjectRazor::Data.instance.check_init
      ProjectRazor::Data.instance.persist_object(model)

      model
    end
    let('model_uuid') do model.uuid end

    subject('slice') do
      ProjectRazor::Slice::Policy.new(%W[
        --template linux_deploy --label test_policy
        --model-uuid #{model_uuid} --tags domaincheck
        --enabled true
      ])
    end

    it "should be possible to add a policy" do
      stdout = console_output_of { slice.add_policy }[:stdout].strip_ansi_color
      stdout.should =~ /Label =>  test_policy/
      stdout.should =~ /Tags =>  \[domaincheck\]/
    end
  end
end
