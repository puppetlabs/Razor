require 'rubygems'                                                                                                                                                                   
require 'rake'
require 'rspec/core/rake_task'

task :default do
  system("rake -T")
end

task :specs => [:spec]

desc "Run all rspec tests"
RSpec::Core::RakeTask.new(:spec) do |t| 
  t.rspec_opts = ['--color']
  # ignores fixtures directory.
  t.pattern = 'spec/**/*_spec.rb'
end

task :specs_html => [:spec_html]

desc "Run all rspec tests with html output"
fpath = "#{ENV['RAZOR_RSPEC_WEBPATH']||'.'}/razor_tests.html"
RSpec::Core::RakeTask.new(:spec_html) do |t| 
  t.rspec_opts = ['--color', '--format h', "--out #{fpath}"]
  # ignores fixtures directory.
  t.pattern = 'spec/**/*_spec.rb'
end
