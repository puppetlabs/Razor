#!/usr/bin/env rspec
require 'spec_helper'

require 'project_razor/cli'

describe ProjectRazor::Cli do

  output = $stdout

  describe 'when parsing global options' do
    it 'should disable color for non-tty STDOUT' do
      args   = ''
      STDOUT.stub(:tty?).and_return(false)
      cli = ProjectRazor::Cli.new(args.split, output).parse_options!
      cli.options[:colorize].should == false
    end

    it 'should disable color when specified' do
      args = '--no-color'
      cli = ProjectRazor::Cli.new(args.split, output).parse_options!
      cli.options[:colorize].should == false
    end

    [ '--debug',
      '-d'
    ].each do |args|
      it 'should enable debug when specified' do
        cli = ProjectRazor::Cli.new(args.split, output).parse_options!
        cli.options[:debug].should == true
      end
    end

    [ '--verbose',
      '-v'
    ].each do |args|
      it 'should enable verbose when specified' do
        cli = ProjectRazor::Cli.new(args.split, output).parse_options!
        cli.options[:verbose].should == true
      end
    end

    [ '--webcommand',
      '-w'
    ].each do |args|
      it 'should enable webcommand when specified' do
        cli = ProjectRazor::Cli.new(args.split, output).parse_options!
        cli.options[:webcommand].should == true
      end
    end

    it 'should parse global options and parse slices' do
      args = '-d image'

      cli = ProjectRazor::Cli.new(args.split, $stdout)
      cli.parse_options!
      cli.parse_slice!
      cli.namespace.should == 'image'
    end

    it 'should throw exception on unknown options' do
      args = '-z'
      expect { ProjectRazor::Cli.new(args.split, output).parse_options! }.should raise_error(OptionParser::InvalidOption)
    end

    it 'should suppress exceptions for webcommand' do
      args = '-w -z'
      output = mock
      output.expects(:puts).never
      cli = ProjectRazor::Cli.new(args.split, output).run
      cli.should == 129
    end
  end

  describe 'when loading slices' do
    it 'should ignore hidden slices for cli' do
      args   = ''
      cli = ProjectRazor::Cli.new(args.split, output).cli_slices
      cli.keys.sort.should == %w( bmc broker image log model node policy tag )
    end

    it 'should find all availble slices' do
      args   = ''
      cli = ProjectRazor::Cli.new(args.split, output).available_slices
      cli.keys.sort.should == %w(base bmc boot broker config image log model node policy tag)
    end

    it 'should display help when no options provided' do
      args = ''
      cli = ProjectRazor::Cli.new(args.split, $stdout)
      cli.should_receive(:display_help)
      cli.run.should == 1
    end

    it 'should display help for invalid slices for cli' do
      args = '-d zzz'
      cli = ProjectRazor::Cli.new(args.split, $stdout)
      cli.should_receive(:puts).with(/Invalid Slice/).once
      cli.should_receive(:display_help)
      cli.run.should == 1
    end

    it 'should return json for invalid slices for webcommand' do
      args = '-w zzz'
      cli = ProjectRazor::Cli.new(args.split, $stdout)
      cli.should_receive(:puts).with(JSON.dump({ "slice" => "ProjectRazor::Slice", "result" => "InvalidSlice", "http_err_code" => 404 }))
      cli.should_receive(:display_help).never
      cli.run.should == 1
    end

    before :each do
      @image = mock(ProjectRazor::Slice::Image)
      @image.stub(:web_command=)
      @image.stub(:verbose=)
      @image.stub(:debug=)
      @image.stub(:slice_call)
    end

    it 'should invoke available slices' do
      args = 'image'

      ProjectRazor::Slice::Image.should_receive(:new).with([]).and_return(@image)
      cli = ProjectRazor::Cli.new(args.split, $stdout)
      cli.stubs(:available_slices).returns({'image'=>ProjectRazor::Slice::Image})
      cli.run.should == 0
    end

    it 'should invoke available slices with command options' do
      args = 'image --help -f baz'

      ProjectRazor::Slice::Image.should_receive(:new).with(['--help', '-f', 'baz']).and_return(@image)
      cli = ProjectRazor::Cli.new(args.split, $stdout)
      cli.stubs(:available_slices).returns({'image'=>ProjectRazor::Slice::Image})
      cli.run.should == 0
    end

    it 'should invoke available slices after stripping global options' do
      args = '-d image -d -f baz'

      ProjectRazor::Slice::Image.should_receive(:new).with(['-d', '-f', 'baz']).and_return(@image)
      cli = ProjectRazor::Cli.new(args.split, $stdout)
      cli.stubs(:available_slices).returns({'image'=>ProjectRazor::Slice::Image})
      cli.run.should == 0
    end
  end
end
