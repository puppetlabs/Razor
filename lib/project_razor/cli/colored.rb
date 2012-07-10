module Colored
  extend self
  def colorize(string, options = {})
    string
  end
end
String.send(:include, Colored)
