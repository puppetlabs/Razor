require 'spec_helper'
require 'project_razor/slice'

describe ProjectRazor::Slice do
  context "code formerly known as SliceUtil::Common" do
    describe "validate_arg" do
      subject('slice') { ProjectRazor::Slice.new([]) }
      it "should return false for empty values" do
        [ nil, {}, '', '{}', '{1}', ['', 1], [nil, 1], ['{}', 1] ].each do |val|
          slice.validate_arg(*[val].flatten).should == false
        end
      end

      it "should return valid value" do
        slice.validate_arg('foo','bar').should == ['foo', 'bar']
      end
    end
  end

  describe "#slice_name" do
    {
      "Bmc"          => "bmc",
      "ActiveRecord" => "active_record"
    }.each do |classname, slicename|
      classname = "ProjectRazor::Slice::#{classname}"
      it "should transform #{classname} into #{slicename}" do
        # This is kind of ugly, thanks Ruby. :/
        klass = Class.new(ProjectRazor::Slice)
        klass.stub(:name => classname)
        klass.new([]).slice_name.should == slicename
      end
    end
  end

  describe "#command_option_data" do
    it "should raise an exception if the command is unknown" do
      expect {
        ProjectRazor::Slice::Node.new([]).command_option_data(:unknown_command)
      }.to raise_error
    end

    it "should return an array if the command is known" do
      ProjectRazor::Slice::Node.new([]).command_option_data(:get).
        should be_an_instance_of Array
    end

    it "should work with string command names" do
      ProjectRazor::Slice::Node.new([]).command_option_data('get').
        should be_an_instance_of Array
    end
  end
end
