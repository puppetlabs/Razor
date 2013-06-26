require 'rubygems'
require 'rake'
require 'yaml'
require 'pathname'

begin
  load File.join(File.dirname(__FILE__), 'ext', 'packaging', 'packaging.rake')
  require 'rspec/core/rake_task'
rescue LoadError
end

task :default do
  system("rake -T")
end

if defined?(RSpec::Core::RakeTask)
  task :specs => [:spec]

  desc "Run all rspec tests"
  RSpec::Core::RakeTask.new(:spec) do |t|
    t.rspec_opts = ['--color']
    # ignores fixtures directory.
    t.pattern = 'spec/**/*_spec.rb'
  end

  task :specsdb => [:specdb]

  desc "Run all rspec Persistence tests"
  RSpec::Core::RakeTask.new(:specdb) do |t|
    t.rspec_opts = ['--color']
    # ignores fixtures directory.
    t.pattern = 'spec/persist/*_spec.rb'
  end

  task :specs_html => [:spec_html]

  desc "Run all rspec tests with html output"
  RSpec::Core::RakeTask.new(:spec_html) do |t|
    fpath = "#{ENV['RAZOR_RSPEC_WEBPATH']||'.'}/razor_tests.html"
    t.rspec_opts = ['--color', '--format h', "--out #{fpath}"]
    # ignores fixtures directory.
    t.pattern = 'spec/**/*_spec.rb'
  end
end

begin
  @build_defaults ||= YAML.load_file('ext/build_defaults.yaml')
  @packaging_url  = @build_defaults['packaging_url']
  @packaging_repo = @build_defaults['packaging_repo']
rescue
  STDERR.puts "Unable to read the packaging repo info from ext/build_defaults.yaml"
end

namespace :package do
  desc "Bootstrap packaging automation, e.g. clone into packaging repo"
  task :bootstrap do
    if File.exist?("ext/#{@packaging_repo}")
      puts "It looks like you already have ext/#{@packaging_repo}. If you don't like it, blow it away with package:implode."
    else
      cd 'ext' do
        %x{git clone #{@packaging_url}}
      end
    end
  end

  desc "Remove all cloned packaging automation"
  task :implode do
    rm_rf "ext/#{@packaging_repo}"
  end
end
