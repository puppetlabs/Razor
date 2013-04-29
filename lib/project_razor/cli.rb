require 'project_razor'

require 'json'
require 'colored'
require 'optparse'

class ProjectRazor::CLI
  # We set a constant for our Slice root Namespace. We use this to pull the
  # slice names back out from objectspace
  SLICE_PREFIX = "ProjectRazor::Slice::"

  # Create a new instance of the CLI dispatcher, ready to service requests.
  def initialize
    @obj = ProjectRazor::Object.new
    @logger = @obj.get_logger
  end

  def run(*argv)
    tmp_argv = argv.dup

    # Preparse args and check for batch mode.
    first_args = get_first_args(tmp_argv)
    first_args.size.times {tmp_argv.shift}
    @options = {}
    optparse = get_optparse
    begin
      optparse.parse(first_args)
    rescue OptionParser::InvalidOption => e
      # We may use this option later so we will continue
      #puts e.message
      #puts optparse
      #exit
    end

    if @options[:batch]
      status = false

      $stdin.each_line do |line|
        if line.strip.empty?
          next
        end

        line_argv = Shellwords.shellwords(line)
        status = run_once(*line_argv)
        $stdout.flush
        if status != true
          return status
        end
      end

      return status
    else
      return run_once(*argv)
    end
  end

  # Run a single invocation of a command line from Razor; this translates the
  # command line into a slice invocation, parsing options along the way, and
  # eventually reports back the result.
  #
  # @param [Array<String>] the command line arguments
  # @return [Boolean] true on success, false on failure
  def run_once(*argv)
    first_args = get_first_args(argv)
    first_args.size.times {argv.shift}
    @options = {}
    optparse = get_optparse
    begin
      optparse.parse(first_args)
    rescue OptionParser::InvalidOption => e
      # We may use this option later so we will continue
      #puts e.message
      #puts optparse
      #exit
    end

    @web_command = @options[:webcommand]
    @cli_private = false

    if @options[:jsoncommand] then
      if @web_command then
        # We do not allow -j if it's combined with -w since that would create
        # security problem.
        puts JSON.dump({
            "slice"         => "ProjectRazor::Slice",
            "result"        => "BadRequest",
            "http_err_code" => 400
          })
        # We must return true here to avoid a "500 Internal Server Error"
        return true
      end
      @web_command = true
      @cli_private = true
    end

    @debug = @options[:debug]
    @verbose = @options[:verbose]

    if @options[:nocolor] or !STDOUT.tty?
      # if this flag is set, override the default behavior of the underlying
      # "colorize" method from the "Colored" module so that it just returns
      # the string that was passed into it (this will have the effect of
      # turning off any color that might be included in any of the output
      # statements involving Strings in Razor)
      ::Colored.module_eval do
        def colorize(string, options = {})
          string
        end
      end
      String.send("include", Colored)
      optparse = get_optparse # reload optparse with color disabled
    end

    slice = argv.shift
    if call_razor_slice(slice, argv)
      return true
    end

    if @web_command then
      puts JSON.dump({
          "slice"         => "ProjectRazor::Slice",
          "result"        => "InvalidSlice",
          "http_err_code" => 404
        })
      # We must return true here to avoid a "500 Internal Server Error"
      return true
    end

    puts optparse
    print_available_slices
    if slice
      print "\n [#{slice}] ".red
      print "<-Invalid Slice \n".yellow
    end
    return false
  end

  private

  def call_razor_slice(raw_name, args)
    return nil if raw_name.nil?

    if raw_name == 'config' and @web_command and !@cli_private then
      @logger.error "Razor config called as web command"
      return false # Will yield 404 which is good. This slice doesn't exist in the web UI
    end

    name = file2const(raw_name)
    razor_module = Object.full_const_get(SLICE_PREFIX + name).new(args)
    razor_module.web_command = @web_command
    razor_module.verbose = @verbose
    razor_module.debug = @debug
    razor_module.slice_call
    return true
  rescue => e
    unless e.to_s =~ /uninitialized constant ProjectRazor::Slice::/
      @logger.error "Razor slice error: #{e.message}"
      print "\n [#{raw_name}] ".red
      print "<- #{e.message} \n".yellow
    end
    raise e if @debug
    return false
  end

  def print_available_slices
    print "\n", "Available slices\n\t".yellow
    x = 1
    slice_path = File.expand_path(File.join(File.dirname(__FILE__), 'slice', '*.rb'))
    slices = Dir.glob(slice_path).map {|f| file2const(File.basename(f,File.extname(f))) }
    slices.sort.uniq.each do |slice|
      slice_obj = ::Object.full_const_get(SLICE_PREFIX + slice).new([])
      unless slice_obj.hidden
        print "[#{const2file(slice)}] ".white
        if x > 5
          print "\n\t"
          x = 0
        end
        x += 1
      end
    end
    print "\n"
  end

  def get_optparse
    OptionParser.new do |opts|
      opts.version   = ProjectRazor::VERSION
      opts.banner    = "#{opts.program_name} - #{opts.version}".green
      opts.separator "Usage: ".yellow
      opts.separator "    razor [slice name] [command argument] [command argument]...".red
      opts.separator ""
      opts.separator "Switches".yellow

      @options[:verbose] = false
      opts.on( '-v', '--verbose', 'Enables verbose object printing'.yellow ) do
        @options[:verbose] = true
      end

      @options[:debug] = false
      opts.on( '-d', '--debug', 'Enables printing proper Ruby stacktrace'.yellow ) do
        @options[:debug] = true
      end

      @options[:webcommand] = false
      opts.on( '-w', '--webcommand', 'Accepts web commands.'.yellow ) do
        @options[:webcommand] = true
      end

      @options[:jsoncommand] = false
      opts.on( '-j', '--jsoncommand', 'Same as -w but not exposed in web UI.'.yellow ) do
        @options[:jsoncommand] = true
      end

      @options[:nocolor] = false
      opts.on( '-n', '--no-color', 'Disables console color. Useful for script wrapping.'.yellow ) do
        @options[:nocolor] = true
      end

      @options[:batch] = false
      opts.on( '-b', '--batch', 'Enables razor to take multiple commands.'.yellow ) do
        @options[:batch] = true
      end

      opts.on_tail('-V', '--version', 'Display the version of Razor'.yellow) do
        puts opts.banner
        exit
      end

      opts.on_tail( '-h', '--help', 'Display this screen'.yellow ) do
        print opts
        print_available_slices
        exit
      end
    end
  end

  def get_first_args(argv)
    f = []
    argv.each do |a|
      if a.start_with?("-")
        f << a
      else
        return f
      end
    end
    f
  end

  # Translate a filename-style constant string into a Ruby-style
  # constant string.  That is, maps `foo_bar` into `FooBar`.
  #
  # @param filename [String] the file-system style name.
  # @return [String] the Ruby style name.
  def file2const(filename)
    filename.to_s.split('_').map(&:capitalize).join
  end

  # Translate a Ruby-style constant string into a file-system style
  # name string.  That is, maps `FooBar` to `foo_bar`.
  #
  # @param const [String] the Ruby style name.
  # @return [String] the file-system style string.
  def const2file(const)
    const.to_s.split(/(?=[A-Z])/).map(&:downcase).join('_')
  end
end
