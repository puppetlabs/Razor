# Ensure that rake or rspec command line arguments don't polite our
# test environment.
ARGV.clear

require 'rspec'
require 'rspec/expectations'

require 'stringio'
require 'tmpdir'

module SpecHelpers
  # Capture and control stdout, stderr, and stdin of some code; used for
  # testing the slices, which unconditionally output text instead of returning
  # something to be output by the caller.
  #
  # @todo danielp 2013-03-18: you should eliminate the need for this by
  # separating the presentation from the action of the code.  Ideally, return
  # objects from all things - including slices - that can be rendered into
  # useful text in their `to_s` method, but which are real Ruby objects.
  def console_output_of(input = '')
    o_stdin, o_stdout, o_stderr = $stdin, $stdout, $stderr
    $stdin, $stdout, $stderr = StringIO.new(input), StringIO.new, StringIO.new
    yield
    { :stdout => $stdout.string, :stderr => $stderr.string }
  ensure
    $stdin, $stdout, $stderr = o_stdin, o_stdout, o_stderr
  end
end

class String
  def strip_ansi_color
    gsub(/\e\[(\d+)m/, '')
  end
end

RSpec.configure do |config|
  # Try and use a custom temporary environment for our work, to reduce the
  # odds that we suffer some sort of race or other attack in our
  # scratch space.
  ENV['TMPDIR'] = ENV['TMP'] = Dir.mktmpdir("razor-rspec-tmp")

  # Make my helper code globally accessible.
  config.include SpecHelpers

  config.before :each do
    # Use the in-memory configuration store, by default.
    ProjectRazor.config['persist_mode'] = :memory
  end

  config.after :each do
    defined?(ProjectRazor::Data) and ProjectRazor::Data.instance.teardown
  end
end
