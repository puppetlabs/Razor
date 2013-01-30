test_name "RSpec based integration tests"
on hosts('razor-server'), "cd /opt/razor && rspec -fd -c spec"
