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
    if stat.size > BUFFER_SIZE
      idx = (stat.size - BUFFER_SIZE)
    else
      next_buffer_size = stat.size
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
      end while lines < ( num_lines + 1 ) && bytes_read < stat.size
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
    end while filter_expression && !first_line_earlier_than_cutoff && matching_lines.size < num_lines && bytes_read < stat.size
    if matching_lines.size < num_lines
      return matching_lines
    end
    lines_to_return = matching_lines[-num_lines..-1]
  end

end

# Root ProjectRazor namespace
module ProjectRazor
  class Slice

    # ProjectRazor Slice Log
    # Used for log viewing
    class Log < ProjectRazor::Slice

      # this regular expression should parse out the timestamp for the
      # message, the log-level, the class-name, the method-name, and the
      # log-message itself into the first to fifth elements of the match_data
      # value returned by a log_line_regexp() call with the input line as
      # an argument to that call (the zero'th element will contain the entire
      # section of the line that matches if there is a match)
      LOG_LINE_REGEXP = /^[A-Z]\,\s+\[([^\s]+)\s+\#[0-9]+\]\s+([A-Z]+)\s+\-\-\s+([^\s\#]+)\#([^\:]+)\:\s+(.*)$/

      # Initializes ProjectRazor::Slice::Log including #slice_commands, #slice_commands_help
      # @param [Array] args
      def initialize(args)

        super(args)
        @hidden = false

        @logfile = File.join(get_logfile_path, "project_razor.log")
      end

      def slice_commands
        { :get => "get_razor_log",
          :default => :get,
          :else => :get
        }
      end

      def all_command_option_data
        {
          :get_razor_log => [
            { :name        => :tail,
              :default     => nil,
              :short_form  => '-t',
              :long_form   => '--tail NLINES',
              :description => 'The number of lines to tail.',
              :uuid_is     => 'not_allowed',
              :required    => false
            },
            { :name        => :log_level,
              :default     => nil,
              :short_form  => '-l',
              :long_form   => '--log-level LOG_LEVEL',
              :description => 'The log level pattern/value.',
              :uuid_is     => 'not_allowed',
              :required    => false
            },
            { :name        => :class_name,
              :default     => nil,
              :short_form  => '-c',
              :long_form   => '--class-name CLASS_NAME',
              :description => 'The class name pattern/value.',
              :uuid_is     => 'not_allowed',
              :required    => false
            },
            { :name        => :method_name,
              :default     => nil,
              :short_form  => '-m',
              :long_form   => '--method-name METHOD_NAME',
              :description => 'The method name pattern/value.',
              :uuid_is     => 'not_allowed',
              :required    => false
            },
            { :name        => :log_message,
              :default     => nil,
              :short_form  => '-g',
              :long_form   => '--log-message LOG_LEVEL',
              :description => 'The log message pattern/value.',
              :uuid_is     => 'not_allowed',
              :required    => false
            },
            { :name        => :elapsed_time,
              :default     => nil,
              :short_form  => '-e',
              :long_form   => '--elapsed-time ELAPSED_TIME',
              :description => 'The elapsed time limit (for messages).',
              :uuid_is     => 'not_allowed',
              :required    => false
            },
            { :name        => :filter_before_tail,
              :default     => false,
              :short_form  => '-n',
              :long_form   => '--filter-before-tail',
              :description => 'Apply filter before tailing (default).',
              :uuid_is     => 'not_allowed',
              :required    => false
            },
            { :name        => :tail_before_filter,
              :default     => false,
              :short_form  => '-r',
              :long_form   => '--tail-before-filter',
              :description => 'Apply tail before filtering.',
              :uuid_is     => 'not_allowed',
              :required    => false
            }
          ]
        }.freeze
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

      def get_razor_log
        @command = :get_razor_log

        # Currently, if it's a web command, then we'll return an error indicating
        # that this slice is not yet implemented as a web command...
        # We'll probably have to work out a separate mechanism for feeding this
        # information back to the Node.js instances (as an ATOM feed of some sort?)
        raise ProjectRazor::Error::Slice::NotImplemented,
              "no web interface exists for the Log slice commands" if @web_command

        # make sure the first argument is actually a flag (if not, it's an error
        # because another resource was slipped into the CLI/RESTful call)
        unless /^[-]{1,2}.*$/.match(@command_array.first)
          raise ProjectRazor::Error::Slice::SliceCommandParsingFailed,
                "Unexpected argument found while parsing log slice command (#{@command_array.first})"
        end

        # load the appropriate option items for the subcommand we are handling
        option_items = command_option_data(:get_razor_log)
        # parse and validate the options that were passed in as part of this
        # subcommand (this method will return a UUID value, if present, and the
        # options map constructed from the @commmand_array)
        tmp, options = parse_and_validate_options(option_items, "razor log (options...)", :require_all)
        includes_uuid = true if tmp && tmp != "get"
        # check for usage errors (the boolean value at the end of this method
        # call is used to indicate whether the choice of options from the
        # option_items hash must be an exclusive choice)
        check_option_usage(option_items, options, includes_uuid, false)

        # extract the filter_options (if any) from the options that were just parsed
        filter_options = {}
        filter_options[:log_level] = options[:log_level] if options[:log_level]
        filter_options[:class_name] = options[:class_name] if options[:class_name]
        filter_options[:method_name] = options[:method_name] if options[:method_name]
        filter_options[:log_message] = options[:log_message] if options[:log_message]
        filter_options[:elapsed_time] = options[:elapsed_time] if options[:elapsed_time]
        # get the first_operation value (and check it)
        tail_before_filter = options[:tail_before_filter]
        filter_before_tail = options[:filter_before_tail]
        if tail_before_filter && filter_before_tail
          raise ProjectRazor::Error::Slice::SliceCommandParsingFailed,
                "only one of the '--tail-before-filter' and '--filter-before-tail' options can be specified"
        elsif !tail_before_filter && !filter_before_tail
          # default is to filter before tailing
          filter_before_tail = true
        end
        # get the number of lines to tail (if included) from the input options
        num_lines_tail = nil
        begin
          num_lines_tail = options[:tail].to_i if options[:tail]
        rescue => e
          raise ProjectRazor::Error::Slice::SliceCommandParsingFailed,
                "Error while converting --tail value to integer: #{e.message}"
        end

        if filter_options.length > 0
          # filter operations were included in the list of options that were passed in
          if num_lines_tail && filter_before_tail
            # number of lines to tail was included, and user wants to filter first
            # (then tail the result of the filtered log)
            filter_then_tail_razor_log(filter_options, num_lines_tail)
          elsif num_lines_tail
            # number of lines to tail was included, and user wants to tail first
            # (then filter the result of the tailed log)
            tail_then_filter_razor_log(filter_options, num_lines_tail)
          else
            # number of lines to tail was not included, so just filter
            filter_razor_log(filter_options)
          end
        elsif num_lines_tail
          # user passed in the number of lines to tail, but no filter options
          tail_razor_log(num_lines_tail)
        else
          # no options were specified, so just view the log
          view_razor_log
        end
      end

      private
      # Prints the contents from the current razor logfile to the command line
      def view_razor_log

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
      def tail_razor_log(num_lines_tail)

        # otherwise, just read and print the tail of the logfile to the command line
        tail_of_file = []
        begin
          tail_of_file = tail_of_file_as_array(num_lines_tail)
        rescue => e
          raise ProjectRazor::Error::Slice::InternalError, "error while reading log file #{@logfile}; #{e.message}"
        end
        tail_of_file.each { |line|
          puts line
        }

      end

      # filters the current razor logfile, printing all matching lines
      def filter_razor_log(filter_options)

        # get the input values for the filter expression from the filter_options
        log_level_str = filter_options[:log_level]
        class_name_str = filter_options[:class_name]
        method_name_str = filter_options[:method_name]
        log_message_str = filter_options[:log_message]
        elapsed_time_str = filter_options[:elapsed_time]

        # construct regular expressions to use for filtering from the non-nil return values
        log_level_match = (log_level_str ? Regexp.new(log_level_str) : nil)
        class_name_match = (class_name_str ? Regexp.new(class_name_str) : nil)
        method_name_match = (method_name_str ? Regexp.new(method_name_str) : nil)
        log_message_match = (log_message_str ? Regexp.new(log_message_str) : nil)

        # then start the process of filtering the log file
        begin

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
      def tail_then_filter_razor_log(filter_options, num_lines_tail)

        # get the input values for the filter expression from the filter_options
        log_level_str = filter_options[:log_level]
        class_name_str = filter_options[:class_name]
        method_name_str = filter_options[:method_name]
        log_message_str = filter_options[:log_message]
        elapsed_time_str = filter_options[:elapsed_time]

        # construct regular expressions to use for filtering from the non-nil return values
        log_level_match = (log_level_str ? Regexp.new(log_level_str) : nil)
        class_name_match = (class_name_str ? Regexp.new(class_name_str) : nil)
        method_name_match = (method_name_str ? Regexp.new(method_name_str) : nil)
        log_message_match = (log_message_str ? Regexp.new(log_message_str) : nil)

        begin

          # and parse the file (first tailing, then filtering the result)
          tail_of_file = tail_of_file_as_array(num_lines_tail)
          # determine the cutoff time to use for printing log file entries
          cutoff_time = (elapsed_time_str ? get_cutoff_time(elapsed_time_str) : nil)
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
      def filter_then_tail_razor_log(filter_options, num_lines_tail)

        # get the input values for the filter expression from the filter_options
        log_level_str = filter_options[:log_level]
        class_name_str = filter_options[:class_name]
        method_name_str = filter_options[:method_name]
        log_message_str = filter_options[:log_message]
        elapsed_time_str = filter_options[:elapsed_time]

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

      # gets the tail of the current logfile as an array of strings
      def tail_of_file_as_array(num_lines_tail, filter_expression = nil, cutoff_time = nil)
        tail_of_file = []
        File.open(@logfile) { |file|
          tail_of_file = file.tail(num_lines_tail, filter_expression, cutoff_time)
        }
        tail_of_file
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
