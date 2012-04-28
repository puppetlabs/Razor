#!/usr/bin/env ruby

# Used to test puppet hand off during development of the plugin


# testing ssh



require 'net/ssh'

Net::SSH.start('192.168.99.144', 'root', :password => "test123") do |ssh|
  # capture all stderr and stdout output from a remote process
  output = ssh.exec!("/usr/bin/env ruby")
  puts output
end



