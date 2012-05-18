
require "project_razor"
require "rspec"

describe ProjectRazor::Tagging::TagRule do

  before (:all) do
    @data = ProjectRazor::Data.instance
    @data.check_init
    @tag_rule = ProjectRazor::Tagging::TagRule.new({"@name" => "RSpec Tag Rule #1", "@tag" => "RSPEC", "@tag_matchers" => []})
  end

  after(:all) do
    @data.delete_all_objects(:tag)
    @data.delete_all_objects(:node)
  end


  it "should be able to create a tag rule" do
    @tag_rule.name.should == "RSpec Tag Rule #1"
    @tag_rule.tag.should == "RSPEC"
    @tag_rule.tag_matchers.should == []
  end

  it "should be able to create a tag matcher within tag rule" do
    @tag_rule.tag.should == "RSPEC"

    @tag_rule.add_tag_matcher(:key => "hostname", :value => 'rspechost[\d]*$', :compare => "like", :inverse => "false").should be_true
  end

  it "should be able to correctly tag with tag rule with single matcher" do
    # based on rule above

    @tag_rule.check_tag_rule({"hostname" => "rspechost123"}).should be_true
    @tag_rule.check_tag_rule({"hostname" => "rspechost9"}).should be_true
    @tag_rule.check_tag_rule({"hostname" => "ANYTHING ELSE"}).should be_false
    @tag_rule.check_tag_rule({"hostname" => "rspechost123n"}).should be_false
  end

  it "should be able to correctly tag with tag rule with multiple matchers" do
    @tag_rule.add_tag_matcher(:key => "ip address",
                              :value => '^192.168.1[2-6].1[0-9][0-9]$',
                              :compare => "like",
                              :inverse => "false").should be_true
    @tag_rule.add_tag_matcher(:key => "building",
                              :value => 'A',
                              :compare => "equal",
                              :inverse => "false").should be_true
    @tag_rule.add_tag_matcher(:key => "secure",
                              :value => 'true',
                              :compare => "equal",
                              :inverse => "true").should be_true
    @tag_rule.add_tag_matcher(:key => "domainname",
                              :value => 'secure-dev\w+',
                              :compare => "like",
                              :inverse => "true").should be_true

    test_hash = {"hostname" => "rspechost123",
                 "ip address" => "192.168.13.165",
                 "building" => "A",
                 "domainname" => "test-dev",
                 "secure" => "false",
                 "junk" => "value"}

    @tag_rule.check_tag_rule(test_hash).should be_true

    test_hash = {"hostname" => "rspechost12n",
                 "ip address" => "192.168.13.165",
                 "building" => "A",
                 "domainname" => "test-dev",
                 "secure" => "false",
                 "junk" => "value"}

    @tag_rule.check_tag_rule(test_hash).should be_false

    test_hash = {"hostname" => "rspechost123",
                 "ip address" => "192.168.13.65",
                 "building" => "A",
                 "domainname" => "test-dev",
                 "secure" => "false",
                 "junk" => "value"}

    @tag_rule.check_tag_rule(test_hash).should be_false

    test_hash = {"hostname" => "rspechost123",
                 "ip address" => "192.168.13.165",
                 "building" => "B",
                 "domainname" => "test-dev",
                 "secure" => "false",
                 "junk" => "value"}

    @tag_rule.check_tag_rule(test_hash).should be_false

    test_hash = {"hostname" => "rspechost123",
                 "ip address" => "192.168.13.165",
                 "building" => "A",
                 "domainname" => "secure-dev01",
                 "secure" => "false",
                 "junk" => "value"}

    @tag_rule.check_tag_rule(test_hash).should be_false

    test_hash = {"hostname" => "rspechost123",
                 "ip address" => "192.168.13.165",
                 "building" => "A",
                 "domainname" => "test-dev01",
                 "secure" => "true",
                 "junk" => "value"}

    @tag_rule.check_tag_rule(test_hash).should be_false


  end

  it "should be able to remove a tag matcher from a tag rule" do
    @tag_rule.refresh_self
    @tag_rule.tag_matchers.count.should == 5

    (1..@tag_rule.tag_matchers.count).each do
      @tag_rule.remove_tag_matcher(@tag_rule.tag_matchers.shift.uuid)
    end



    @tag_rule.tag_matchers.count.should == 0
  end
end
