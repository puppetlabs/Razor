#!/usr/bin/ruby
require 'spec_helper'

describe "Puppet broker agent install script (ERB)" do
  let :content do
    File.read(File.join(File.dirname(__FILE__), '../../../lib/project_razor/broker/puppet/agent_install.erb'))
  end

  before :each do
    # Unfortunately, we actually do need to use member variables here.
    # ERB only looks at local binding context, and the templates depend on
    # member variables of the class that manages them.
    @options = {}
  end

  it "should compile" do
    ERB.new(content).result(binding)
  end
end
