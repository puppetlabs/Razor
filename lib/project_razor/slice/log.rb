# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved

require "json"
require "time"
require "pp"

# Root namespace for LogViewer objects
# used to find them in object space for type checking
LOGVIEWER_PREFIX = "ProjectRazor::LogViewer::"

# do a bit of "monkey-patching" of the File class so that we'll have access to a few
# additional methods from within our Logviewer Slice
class File

  # First, define a buffer size that is used for reading the file in chunks
  # in the each_chunk and tail methods, below
  BUFFER_SIZE = 4096

  # and define the default number of lines to include in a "tail" if not
  # specified in the input to the "tail" function (or if the value that
  # is passed in is a nil value)
  DEFAULT_NLINES_TAIL = 10

  # Here, we extend the File class with a new method (each_chunk) that can
  # be used to iterate through a file and return that file to the caller
  # in chunks of "chunk_size" bytes
  #
  # @param [Integer] chunk_size
  # @return [Object]
  def each_chunk(chunk_size=BUFFER_SIZE)
    yield read(chunk_size) until eof?
  end

  # Here, we extend the File class with a new method (tail) that will return
  # the last N lines from the corresponding file to the caller (as an array)
  #
  # @param [Integer] num_lines - the number of lines to read from from the "tail" of
  # the file (defaults to DEFAULT_NLINES_TAIL lines if not included in the method call)
  # @return [Array]  the last N lines from the file, where N is the input argument
  # (or the entire file if the number of lines is less than N)
  def tail(num_lines=DEFAULT_NLINES_TAIL, filter_expression = nil, cutoff_time = nil)
    # if the number of lines passed in is nil, use the default value instead
    num_lines = DEFAULT_NLINES_TAIL unless num_lines
    # initialize a few variables
    idx = 0
    bytes_read = 0
    next_buffer_size = BUFFER_SIZE
    # handle the case where the file size is less than the BUFFER_SIZE
    # correctly (in that case, will read the entire file in one chunk)
    if size > BUFFER_SIZE
      idx = (size - BUFFER_SIZE)
    else
      next_buffer_size = size
    end
    lines = 0
    # this flag is only set if a cutoff time is included
    first_line_earlier_than_cutoff = false
    # and this array is used to hold the "matching lines" that are read
    # from the file
    matching_lines = []
    begin
      # As long as we haven't read the number of lines requested
      # and we haven't read the entire file, loop through the file
      # and read it in chunks
      chunks = []
      begin
        # seek to the appropriate position to read the next chunk, then
        # read it
        seek(idx)
        chunk = read(next_buffer_size)
        # count the number of lines in the chunk we just read and add that
        # chunk to the buffer; while we are at it, determine how many bytes
        # were just read and increment the total number of bytes read
        lines += chunk.count("\n")
        chunks.unshift chunk
        bytes_read += chunk.size
        # if there is more than a buffer prior to the chunk we just read, then
        # shift back by an entire buffer for the next read, otherwise just
        # move back to the start of the file and set the next_buffer_size
        # appropriately
        if idx > BUFFER_SIZE
          next_buffer_size = BUFFER_SIZE
          idx -= BUFFER_SIZE
        else
          next_buffer_size = idx
          idx = 0
        end
        # loop until this chunk contains enough lines to satisfy the requested
        # tail size (note; this may not be enough if a filter criteria was included
        # that filters out some of these lines, but it's a start)
      end while lines < ( num_lines + 1 ) && bytes_read < size
      # now that we've got enough "raw lines" to (potentially)satisfy the requested
      # number of lines (or the entire file has been read into the buffer), concatenate
      # the array of chunks and split the result into lines
      tail_of_file = chunks.join('')
      chunk_lines = tail_of_file.split(/\n/)
      # if a filter expression was included, use that to select out only matching lines
      # from the lines found so far, else just add all of the chunk lines found
      # to the "matching_lines" array (in which case we should be done)
      if filter_expression
        # note; if a filter expression is included, this may result in fewer lines
        # than were requested, in which case we have to repeat the procedure (above)
        # until we find enough matching lines
        match_data = []
        chunk_lines.each { |line|
          match_data = filter_expression.match(line)
          break if match_data
        }
        next unless match_data
        log_line_time = Time.parse(match_data[1]) if match_data
        first_line_earlier_than_cutoff = (log_line_time < cutoff_time) if cutoff_time
        # select out only the lines that match the input filter expression and have a time
        # greater than or equal to the cutoff_time (if it was included)
        chunk_matching_lines = chunk_lines.select { |line|
          match_data = filter_expression.match(line)
          after_cutoff = true
          if match_data && cutoff_time
            log_line_time = Time.parse(match_data[1])
            after_cutoff = (log_line_time > cutoff_time)
          end
          (match_data && after_cutoff)
        }
        if matching_lines.size > 0 && chunk_matching_lines
          matching_lines = chunk_matching_lines.concat(matching_lines)
        elsif chunk_matching_lines
          matching_lines.concat(chunk_matching_lines)
        end
        # reset the "lines" value to the number of lines we found that matched, then
        # continue the loop (if that's not enough to satisfy the requested number of
        # tailed lines)
        lines = matching_lines.size
      else
        matching_lines.concat(chunk_lines)
      end
      # loop until we've found enough lines or have read the entire file
    end while filter_expression && !first_line_earlier_than_cutoff && matching_lines.size < num_lines && bytes_read < size
    if matching_lines.size < num_lines
      return matching_lines
    end
    lines_to_return = matching_lines[-num_lines..-1]
  end

end

# and monkey patch the JSON class to add an is_json? method
# TODO - Change to default .to_json already in util
module JSON
  def self.is_json?(foo)
    begin
      return false unless foo.is_a?(String)
      JSON.parse(foo).all?
    rescue JSON::ParserError
      false
    end
  end
end

# Root ProjectRazor namespace
# @author Nicholas Weaver
module ProjectRazor
  module Slice

    # ProjectRazor Slice Log
    # Used for log viewing
    # @author Tom McSweeney
    class Log < ProjectRazor::Slice::Base

      # this regular expression should parse out the timestamp for the
      # message, the log-level, the class-name, the method-name, and the
      # log-message itself into the first to fifth elements of the match_data
      # value returned by a log_line_regexp() call with the input line as
      # an argument to that call (the zero'th element will contain the entire
      # section of the line that matches if there is a match)
      LOG_LINE_REGEXP = /^[A-Z]\,\s+\[([^\s]+)\s+\#[0-9]+\]\s+([A-Z]+)\s+\-\-\s+([^\s\#]+)\#([^\:]+)\:\s+(.*)$/

      # Initializes ProjectRazor::Slice::Log including #slice_commands, #slice_commands_help, & #slice_name
      # @param [Array] args
      def initialize(args)

        super(args)
        @hidden = false
        @new_slice_style = true # switch to new slice style

        # define a few "help strings" (for the tail and filter commands)
        tail_help_str = "razor logviewer tail [NLINES] [filter EXPR]"
        filter_help_str = "razor logviewer filter EXPR [tail [NLINES]]"
        general_help_str = "razor logviewer [tail [NLINES]] [filter EXPR]"
        # Here we create a hash of the command string to the method it corresponds to for routing.
        @slice_commands = {:tail => { /^[0-9]+$/ => {:default => "tail_razor_log",
                                                     :filter => "tail_then_filter_razor_log",
                                                     :else => :help,
                                                     :help => tail_help_str},
                                      :filter => "tail_then_filter_razor_log",
                                      :default => "tail_razor_log",
                                      :else => :help,
                                      :help => tail_help_str},
                           :filter => "filter_razor_log",
                           :default => "view_razor_log",
                           :else => :help,
                           :help => general_help_str
        }
        @slice_name = "Log"
        @logfile = File.join(get_logfile_path, "project_razor.log")
      end

      # uses the location of the Razor configuration file to determine the path to the
      # ${RAZOR_HOME}/log directory (which is where the logfiles for Razor are located)
      def get_logfile_path
        # split the path into an array using the File::SEPARATOR as the separator
        conf_dir_parts =  $config_server_path.split(File::SEPARATOR)
        # and extract all but the last two pieces (which will contain the configuration
        # directory name and the name of the configuration file)
        logfile_path_parts = conf_dir_parts[0...-2]
        # append the "log" directory name to the array, and join that array back together
        # using the File.join() method
        logfile_path_parts << "log"
        File.join(logfile_path_parts)
      end

      # Prints the contents from the current razor logfile to the command line
      def view_razor_log

        # if it's a web command, return an error indicating that this method is not
        # yet implemented as a web command.  We'll probably have to work out a
        # separate mechanism for feeding this information back to the Node.js
        # instances as an ATOM feed of some sort
        raise ProjectRazor::Error::Slice::NotImplemented,
              "no web interface exists for the Log slice commands" if @web_command

        # otherwise, just read the logfile and print the contents to the command line
        begin
          File.open(@logfile, 'r').each_chunk { |chunk|
            print chunk
          }
        rescue => e
          # if get to here, there was an issue reading the logfile, return the error
          raise ProjectRazor::Error::Slice::InternalError, "error while reading log file #{@logfile}; #{e.message}"
        end

      end

      # Prints the tail of the current razor logfile to the command line
      def tail_razor_log

        # if it's a web command, return an error indicating that this method is not
        # yet implemented as a web command.  We'll probably have to work out a
        # separate mechanism for feeding this information back to the Node.js
        # instances as an ATOM feed of some sort
        raise ProjectRazor::Error::Slice::NotImplemented,
              "no web interface exists for the Log slice commands" if @web_command

        # otherwise, just read and print the tail of the logfile to the command line
        tail_of_file = []
        begin
          last_arg = @prev_args.look
          num_lines_tail = nil
          # if the last argument is an integer, us it as the number of lines
          if /[0-9]+/.match(last_arg)
            num_lines_tail = last_arg.to_i
          end
          tail_of_file = tail_of_file_as_array(num_lines_tail)
        rescue => e
          raise ProjectRazor::Error::Slice::InternalError, "error while reading log file #{@logfile}; #{e.message}"
        end
        tail_of_file.each { |line|
          puts line
        }

      end

      # filters the current razor logfile, printing all matching lines
      def filter_razor_log

        # if it's a web command, return an error indicating that this method is not
        # yet implemented as a web command.  We'll probably have to work out a
        # separate mechanism for feeding this information back to the Node.js
        # instances as an ATOM feed of some sort
        raise ProjectRazor::Error::Slice::NotImplemented,
              "no web interface exists for the Log slice commands" if @web_command

        begin
          return filter_then_tail_razor_log if @command_array.include?("tail")
          # get the input name=value pairs for the filter expression (if any) from the command line
          log_level_str, elapsed_time_str, class_name_str,
              method_name_str, log_message_str = get_filter_criteria
          # construct regular expressions to use for filtering from the non-nil return values
          log_level_match = (log_level_str ? Regexp.new(log_level_str) : nil)
          class_name_match = (class_name_str ? Regexp.new(class_name_str) : nil)
          method_name_match = (method_name_str ? Regexp.new(method_name_str) : nil)
          log_message_match = (log_message_str ? Regexp.new(log_message_str) : nil)
          # initialize a few variables
          incomplete_last_line = false
          prev_line = ""
          last_complete_line = ""
          past_time = false
          # determine the cutoff time to use for printing log file entries
          cutoff_time = get_cutoff_time(elapsed_time_str)

          # and loop through the file in chunks, parsing each chunk and filtering out
          # the lines that don't match the criteria parsed from the filter expresssion
          # passed into the command (above)
          File.open(@logfile, 'r').each_chunk { |chunk|

            line_array = []

            # split the chunk into a line array using the newline character as a delimiter
            line_array.concat(chunk.split("\n"))
            # if the last chunk had an incomplete last line, then add it to the start
            # of the first element of the line_array
            if incomplete_last_line
              line_array[0] = prev_line + line_array[0]
            end

            # test to see if this chunk ends with a newline or not, if not then the last
            # line of this chunk is incomplete; will be important later on
            incomplete_last_line = (chunk.end_with?("\n") ? false : true)
            if incomplete_last_line
              prev_line = line_array[-1]
            else
              prev_line = ""
            end

            # initialize a few variables, then loop through all of the lines in this chunk
            filtered_chunk = ""
            nlines_chunk = chunk.count("\n"); count = 0

            # get the index of the last complete line from the chunk we just read
            if cutoff_time && !past_time && incomplete_last_line
              last_complete_line = line_array[-2]
            elsif cutoff_time && !past_time
              last_complete_line = line_array[-1]
            end

            # if the cutoff time wasn't specified as part of the search
            # criteria or if we've already found a line that is past the
            # time we're looking for, then we can continue, otherwise only
            # continue if the last complete line in this chunk is after
            # the specified cutoff time
            next unless !cutoff_time || past_time || was_logged_after_time(last_complete_line, cutoff_time)

            line_array.each { |line|

              next if incomplete_last_line && count == nlines_chunk

              # if we haven't found a line after the cutoff time yet, then check to see
              # if the timestamp of this line is after the cutoff time.  If so, then we'll
              # set "past_time" to true (to avoid further uneccesary time checks) and
              # start adding matching lines (if any) to our filtered_chunk.  If not, then
              # move on to the next line
              unless past_time
                next unless was_logged_after_time(line, cutoff_time)
                past_time = true
              end

              # otherwise, grab add the line to the filtered_chunk if it matches and
              # increment our counter
              if line_matches_criteria(line, log_level_match, class_name_match,
                                       method_name_match, log_message_match)
                filtered_chunk << line + "\n"
              end
              count += 1

            }
            print filtered_chunk if filtered_chunk.length > 0
          }
        rescue => e
          # if get to here, there was an issue parsing the filter criteria or
          # reading the logfile, return that error
          raise ProjectRazor::Error::Slice::InternalError, "error while filtering log file #{@logfile}; #{e.message}"
        end

      end

      # tails the current razor logfile, then filters the result
      def tail_then_filter_razor_log

        # if it's a web command, return an error indicating that this method is not
        # yet implemented as a web command.  We'll probably have to work out a
        # separate mechanism for feeding this information back to the Node.js
        # instances as an ATOM feed of some sort
        raise ProjectRazor::Error::Slice::NotImplemented,
              "no web interface exists for the Log slice commands" if @web_command

        begin
          # then, peek one element down in the stack of previous arguments (which should be
          # which should be the number of lines to tail before filtering).  Note:  if no
          # NLINES argument was specified in the command, then the second element down in
          # the stack will actually be the string "tail" ()rather than the number of lines
          # to tail off of the file before filtering).  In that case, we ensure that the
          # num_lines_tail value is set to nil rather than attempting to convert the string
          # "tail" into an integer (all other error conditions should be handled in the
          # logic of the @slice_commands hash defined above)
          num_lines_tail_str = @prev_args.peek(1)
          num_lines_tail = (num_lines_tail_str == "tail" ? nil : num_lines_tail_str.to_i)
          # get the input name=value pairs for the filter expression (if any) from the command line
          log_level_str, elapsed_time_str, class_name_str,
              method_name_str, log_message_str = get_filter_criteria
          # construct regular expressions to use for filtering from the non-nil return values
          log_level_match = (log_level_str ? Regexp.new(log_level_str) : nil)
          class_name_match = (class_name_str ? Regexp.new(class_name_str) : nil)
          method_name_match = (method_name_str ? Regexp.new(method_name_str) : nil)
          log_message_match = (log_message_str ? Regexp.new(log_message_str) : nil)
          # and parse the file (first tailing, then filtering the result)
          tail_of_file = tail_of_file_as_array(num_lines_tail)
          # determine the cutoff time to use for printing log file entries
          cutoff_time = get_cutoff_time(elapsed_time_str)
          past_time = false
          # loop through the tailed lines, extracting the lines that match
          tail_of_file.each { |line|
            next unless !cutoff_time || past_time || was_logged_after_time(line, cutoff_time)
            past_time = true if !cutoff_time && !past_time
            puts line if line_matches_criteria(line, log_level_match, class_name_match,
                                               method_name_match, log_message_match)
          }
        rescue => e
          raise ProjectRazor::Error::Slice::InternalError, "error while tailing, then filtering log file #{@logfile}; #{e.message}"
        end

      end

      # filters the current razor logfile, then tails the result
      def filter_then_tail_razor_log

        # if it's a web command, return an error indicating that this method is not
        # yet implemented as a web command.  We'll probably have to work out a
        # separate mechanism for feeding this information back to the Node.js
        # instances as an ATOM feed of some sort
        raise ProjectRazor::Error::Slice::NotImplemented,
              "no web interface exists for the Log slice commands" if @web_command

        # get the input name=value pairs for the filter expression (if any) from the command line
        log_level_str, elapsed_time_str, class_name_str,
            method_name_str, log_message_str = get_filter_criteria
        # grab the next argument from the @command_array (which should be the command "tail")
        # and then grab the number of lines to tail.  If there is no "last argument", then
        # no number of lines were include, so just set the num_lines_tail to nil and move on
        next_cmd = get_next_arg
        num_lines_tail_str = get_next_arg
        num_lines_tail = (num_lines_tail_str ? num_lines_tail_str.to_i : nil)
        filter_expression = get_regexp_match(log_level_str, class_name_str, method_name_str, log_message_str)
        tail_of_file = []
        begin
          cutoff_time = (elapsed_time_str ? get_cutoff_time(elapsed_time_str) : nil)
          tail_of_file = tail_of_file_as_array(num_lines_tail, filter_expression, cutoff_time)
        rescue => e
          raise ProjectRazor::Error::Slice::InternalError, "error while filtering, then tailing log file #{@logfile}; #{e.message}"
        end
        tail_of_file.each { |line|
          puts line
        }

      end

      private
      # gets the tail of the current logfile as an array of strings
      def tail_of_file_as_array(num_lines_tail, filter_expression = nil, cutoff_time = nil)
        tail_of_file = []
        File.open(@logfile) { |file|
          tail_of_file = file.tail(num_lines_tail, filter_expression, cutoff_time)
        }
        tail_of_file
      end

      # parses the input filter_expr_string from the underlying @command_array and returns
      # an array of the various types of filter criteria that could be included
      def get_filter_criteria
        # get the name=value pairs from the command line (recognized names are one or more
        # of the expected_names argument passed into the get_name_value_args, below)
        return_vals = get_name_value_args(%W[log_level elapsed_time class_name method_name log_message])
        # now, parse the return_vals to get the parts (should be a set of key-value pairs where the
        # values are regular expressions and the keys are one or more of the following: log_level,
        # elapsed_time, class_name, or pattern)
        log_level_str, elapsed_time_str = return_vals["log_level"], return_vals["elapsed_time"]
        class_name_str, method_name_str = return_vals["class_name"], return_vals["method_name"]
        log_message_str = return_vals["log_message"]
        # and return the results to the caller
        [log_level_str, elapsed_time_str, class_name_str, method_name_str, log_message_str]
      end

      def get_cutoff_time(elapsed_time_str)
        match_data = /([0-9]+)(s|m|h|d)?/.match(elapsed_time_str)
        if match_data
          match_on_time = true
          case match_data[2]
            when nil
              offset = match_data[1].to_i
            when "s"
              offset = match_data[1].to_i
            when "m"
              offset = match_data[1].to_i * 60
            when "h"
              offset = match_data[1].to_i * 3600
            when "d"
              offset = match_data[1].to_i * 3600 * 24
            else
              raise ProjectRazor::Error::Slice::SliceCommandParsingFailed,
                    "Unrecognized suffix '#{match_data[2]}' in elapsed_time_str value '#{elapsed_time_str}'"
          end
          return (Time.now - offset)
        end
        return nil
      end

      # used to determine if a line matches the input filter criteria (regular expressions
      # for the log_level, class_name, method_name, or log_message that are parsed from the line
      # using a regular expression).  If any of the regular expressions are nil, then they
      # represent a wildcarded value (any of that type of field will match)
      def line_matches_criteria(line_to_test, log_level_match, class_name_match,
          method_name_match, log_message_match)
        match_data = LOG_LINE_REGEXP.match(line_to_test)
        # if the match_data value is nil, then the parsing failed and there is no match
        # with this line, so return false
        return false unless match_data
        # check to see if the current line matches our criteria (if one of the criteria
        # is nil, anything is assumed to match that criteria)
        if (!log_level_match || log_level_match.match(match_data[2])) &&
            (!class_name_match || class_name_match.match(match_data[3])) &&
            (!method_name_match || method_name_match.match(match_data[4])) &&
            (!log_message_match || log_message_match.match(match_data[5]))
          return true
        end
        false
      end

      # used to get a regular expression that can be used to select matching
      # lines from the logfile based on the input filter criteria
      def get_regexp_match(log_level_str, class_name_str, method_name_str, log_message_str)
        regexp_string = '^[A-Z]\,\s+\[([^\s]+)\s+\#[0-9]+\]\s+LOG_LEVEL_STR\s+\-\-\s+CLASS_NAME_STR\#METHOD_STR\:\s+LOG_MESSAGE_STR$'
        regexp_string["LOG_LEVEL_STR"] = (log_level_str ? "(.*#{log_level_str}.*)" : "[A-Z]+")
        regexp_string["CLASS_NAME_STR"] = (class_name_str ? "(.*#{class_name_str}.*)" : "([^\s\#]+)")
        regexp_string["METHOD_STR"] = (method_name_str ? "(.*#{method_name_str}.*)" : "([^\:]+)")
        regexp_string["LOG_MESSAGE_STR"] = (log_message_str ? "(.*#{log_message_str}.*)" : "(.*)")
        Regexp.new(regexp_string)
      end

      # used to determine if a line from the logfile is after the cutoff_time
      def was_logged_after_time(line_to_test, cutoff_time)
        return true unless cutoff_time
        match_data = LOG_LINE_REGEXP.match(line_to_test)
        # if the line doesn't match the regular expression for our log lines, then we have
        # no way to test and see if it occurs after the specified time.  As such, return false
        return false unless match_data
        log_line_time = Time.parse(match_data[1])
        # return a boolean indicating whether or not the time in the log line is greater than
        # or equal to the cutoff time
        log_line_time >= cutoff_time
      end

    end
  end
end
