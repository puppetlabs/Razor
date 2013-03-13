require 'spec_helper'
require 'project_razor/utility'

describe ProjectRazor::Utility do

  describe ".encode_symbols_in_hash" do

    it "leaves existing hash values unmodified" do
      ProjectRazor::Utility.encode_symbols_in_hash({
        'a' => 'b'
      }).should eq({
        'a' => 'b'
      })
    end

    it "encodes nested hash values that are symbols" do
      ProjectRazor::Utility.encode_symbols_in_hash({
        'a' => :b,
        'nested' => { 'c' => :d }
      }).should eq({
        'a' => ':b',
        'nested' => { 'c' => ':d' }
      })
    end

    it "traverses arrays" do
      ProjectRazor::Utility.encode_symbols_in_hash({
        'arr' => [
          { 'a' => 'b' },
          { 'c' => { 'd' => :e } },
          { 'deeper' => [ { 'f' => :g }] }
        ]
      }).should eq({
        'arr' => [
          { 'a' => 'b' },
          { 'c' => { 'd' => ':e' } },
          { 'deeper' => [ { 'f' => ':g' }] }
        ]
      })
    end
  end

  describe ".decode_symbols_in_hash" do

    it "leaves existing hash values unmodified" do
      ProjectRazor::Utility.decode_symbols_in_hash({
        'a' => 'b'
      }).should eq({
        'a' => 'b'
      })
    end

    it "decodes nested hash values that are symbols" do
      ProjectRazor::Utility.decode_symbols_in_hash({
        'a' => ':b',
        'nested' => { 'c' => ':d' }
      }).should eq({
        'a' => :b,
        'nested' => { 'c' => :d }
      })
    end

    it "traverses arrays" do
      ProjectRazor::Utility.decode_symbols_in_hash({
        'arr' => [
          { 'a' => 'b' },
          { 'c' => { 'd' => ':e' } },
          { 'deeper' => [ { 'f' => ':g' }] }
        ]
      }).should eq({
        'arr' => [
          { 'a' => 'b' },
          { 'c' => { 'd' => :e } },
          { 'deeper' => [ { 'f' => :g }] }
        ]
      })
    end
  end
end
