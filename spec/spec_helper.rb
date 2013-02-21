# Ensure that rake or rspec command line arguments don't polite our
# test environment.
ARGV.clear

require 'rspec'
require 'rspec/expectations'

require 'tmpdir'

RSpec.configure do |config|
  # Try and use a custom temporary environment for our work, to reduce the
  # odds that we suffer some sort of race or other attack in our
  # scratch space.
  ENV['TMPDIR'] = ENV['TMP'] = Dir.mktmpdir("razor-rspec-tmp")
end
