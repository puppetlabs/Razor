require 'spec_helper'
require 'project_razor/slice'

describe ProjectRazor::Slice do
  # before :each do
  #   @test = TestClass.new
  #   @test.extend(ProjectRazor::SliceUtil::Common)
  #   # TODO: Review external dependencies here:
  #   @test.extend(ProjectRazor::Utility)
  # end

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
end
