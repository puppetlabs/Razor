#!/usr/bin/env rspec
require 'spec_helper'

require 'project_razor/utility'

describe ProjectRazor::SliceUtil::Common do

  class TestClass
  end

  before :each do
    @test = TestClass.new
    @test.extend(ProjectRazor::SliceUtil::Common)
    # TODO: Review external dependencies here:
    @test.extend(ProjectRazor::Utility)
  end

  describe "get_web_args" do
    it "should return value for matching key" do
      @test.stub(:command_shift){'{"@k1":"v1","@k2":"v2","@k3":"v3"}'}
      @test.get_web_vars(['k1', 'k2']).should == ['v1','v2']
    end

    it "should return nil element for nonmatching key" do
      @test.stub(:command_shift){'{"@k1":"v1","@k2":"v2","@k3":"v3"}'}
      @test.get_web_vars(['k1', 'k4']).should == ['v1', nil]
    end

    it "should return nil for invalid JSON" do
      @test.stub(:command_shift){'\3"}'}
      @test.get_web_vars(['k1', 'k2']).should == nil
    end
  end

  describe "get_cli_args" do
    it "should return value for matching key" do
      @test.stub(:command_array){["template=debian_wheezy", "label=debian", "image_uuid=3RpS0x2KWmITuAsHALa3Ni"]}
      @test.get_cli_vars(['template', 'label']).should == ['debian_wheezy','debian']
    end

    it "should return nil element for nonmatching key" do
      @test.stub(:command_array){["template=debian_wheezy", "label=debian", "image_uuid=3RpS0x2KWmITuAsHALa3Ni"]}
      @test.get_cli_vars(['template', 'foo']).should == ['debian_wheezy', nil]
    end
  end

  describe "validate_arg" do
    it "should return false for empty values" do
      [ nil, {}, '', '{}', '{1}', ['', 1], [nil, 1], ['{}', 1] ].each do |val|
        @test.validate_arg(*[val].flatten).should == false
      end
    end

    it "should return valid value" do
      @test.validate_arg('foo','bar').should == ['foo', 'bar']
    end
  end

end
