require 'spec_helper'
require 'project_razor/tagging/tag_rule'

describe ProjectRazor::Tagging::TagRule do
  # REVISIT: this is a stub - we test that we can load the code, which is
  # better than no testing at all, but not actually very interesting in the
  # bigger picture.  When we write any real test for the class then this
  # next to useless test should be removed. --daniel 2013-02-21
  it "should exist as a constant" do
    described_class.should be
  end

  describe ".add_tag_matcher" do
    before :each do
      @tag_rule = ProjectRazor::Tagging::TagRule.new({})
      @tag_matcher_options = {
        :key     => 'foo',
        :value   => 'bar',
        :compare => 'like',
        :inverse => 'false',
      }
    end

    it "should return a tag_matcher when passed valid options" do
      @tag_rule.add_tag_matcher(@tag_matcher_options).
        should be_an_instance_of ProjectRazor::Tagging::TagMatcher
    end

    [:key, :value].each do |option|
      describe "#{option} option" do
        [true, false, [], {}].each do |object|
          it "should return false when passed class #{object.class}" do
            options = @tag_matcher_options.merge({option => object})
            @tag_rule.add_tag_matcher(options).should be false
          end
        end
      end
    end

    describe "compare option" do
      ['equal', 'like'].each do |compare|
        it "should return a tag_matcher when passed #{compare.inspect}" do
          options = @tag_matcher_options.merge({:compare => compare})
          @tag_rule.add_tag_matcher(options).
            should be_an_instance_of ProjectRazor::Tagging::TagMatcher
        end
      end

      it "should return false when passed \"foo\"" do
        options = @tag_matcher_options.merge({:compare => 'foo'})
        @tag_rule.add_tag_matcher(options).should be false
      end
    end

    describe "inverse option" do
      [true, false, 'true', 'false'].each do |inverse|
        it "should return a tag_matcher when passed #{inverse.inspect}" do
          options = @tag_matcher_options.merge({:inverse => inverse})
          @tag_rule.add_tag_matcher(options).
            should be_an_instance_of ProjectRazor::Tagging::TagMatcher
        end
      end

      it "should return false when passed \"foo\"" do
        options = @tag_matcher_options.merge({:inverse => 'foo'})
        @tag_rule.add_tag_matcher(options).should be false
      end
    end
  end
end
