
require "json"

module ProjectRazor
  module SliceUtil
    module Common

      # here, we define a Stack class that simply delegates the equivalent "push", "pop",
      # "to_s" and "clear" calls to the underlying Array object using the delegation
      # methods provided by Ruby through the Forwardable class.  We could do the same
      # thing using an Array, but that wouldn't let us restrict the methods that
      # were supported by our Stack to just those methods that a stack should have

      require "forwardable"

      class Stack
        extend Forwardable
        def_delegators :@array, :push, :pop, :to_s, :clear, :count

        # initializes the underlying array for the stack
        def initialize
          @array = []
        end

        # looks at the last element pushed onto the stack
        def look
          @array.last
        end

        # peeks down to the n-th element in the stack (zero is the top,
        # if the 'n' value that is passed is deeper than the stack, it's
        # an error (and will result in an IndexError being thrown)
        def peek(n = 0)
          stack_idx = -(n+1)
          @array[stack_idx]
        end

      end

      #class ObjectTemplate < ProjectRazor::Object
      #  attr_accessor :template, :description
      #
      #  def initialize(options = {})
      #    @template = options[:template]
      #    @description = options[:description]
      #  end
      #
      #  def print_header
      #    return "Template", "Description"
      #  end
      #
      #  def print_items
      #    return @template, @description
      #  end
      #
      #  def line_color
      #    :white_on_black
      #  end
      #
      #  def header_color
      #    :red_on_black
      #  end
      #end
      #
      #class ObjectPlugin < ObjectTemplate
      #  attr_accessor :plugin, :description
      #
      #  def initialize(options = {})
      #    @plugin = options[:plugin]
      #    @description = options[:description]
      #  end
      #
      #  def print_header
      #    return "Plugin", "Description"
      #  end
      #
      #  def print_items
      #    return @plugin, @description
      #  end
      #end
      #
      #class ObjectModelTemplate < ObjectTemplate
      #  attr_accessor :template, :description, :req_metadata
      #
      #  def initialize(options = {})
      #    @template = options[:template]
      #    @description = options[:description]
      #    @req_metadata_hash = options[:req_metadata_hash]
      #  end
      #
      #  def print_header
      #    return "Template", "Description"
      #  end
      #
      #  def print_items
      #    return @template, @description
      #  end
      #end

      def get_web_vars(vars_array)
          json_string = @command_array.shift
          # Validate JSON, if valid we treat like a POST VAR request. Otherwise it passes on to CLI which handles GET like CLI
          return nil unless is_valid_json?(json_string)
          vars_hash = sanitize_hash(JSON.parse(json_string))
          vars_found_array = []
          vars_array.each do
            |vars_name|
            vars_found_array << vars_hash[vars_name]
          end
          vars_found_array
      end

      def get_cli_vars(vars_array)
        vars_found_array = []
        vars_array.each do
        |vars_name|
          var_value = nil
          @command_array.each do
            |arg|
            var_value = arg.sub(/^#{vars_name}=/,"") if arg.start_with?(vars_name)
          end
          vars_found_array << var_value
        end
        vars_found_array
      end

      def get_noun(classname)
        noun = nil
        begin
          File.open(File.join(File.dirname(__FILE__), "api_mapping.yaml")) do
          |file|
            api_map = YAML.load(file)

            api_map.sort! {|a,b| a[:namespace].length <=> b[:namespace].length}.reverse!
            api_map.each do
            |api|
              noun = api[:noun] if classname.start_with?(api[:namespace])
            end
          end
        rescue => e
          logger.error e.message
          return nil
        end
        noun
      end

      # Returns all child templates from prefix
      def get_child_templates(namespace_prefix)
        temp_hash = {}
        ObjectSpace.each_object do |object_class|
          if object_class.to_s.start_with?(namespace_prefix) && object_class.to_s != namespace_prefix && !(object_class.to_s =~ /#/)
            unless object_class.is_a? String or object_class.is_a? Hash or object_class.is_a? Array
              temp_hash[object_class.to_s] = object_class.to_s.sub(namespace_prefix,"").strip
            end
          end
        end

        object_array = {}
        temp_hash.each_value {|x| object_array[x] = x}

        objects = object_array.values.sort.collect {|x| ::Object::full_const_get((namespace_prefix + x)).new({}) }
        objects.each {|object| object.is_template = true}
        valid_objects = []
        objects.each {|object| valid_objects << object unless object.hidden}
        valid_objects
      end


      alias :get_child_types :get_child_templates

      # returns child templates as ObjectTemplate (used for printing)
      #def get_object_template(namespace_prefix)
      #  get_child_templates(namespace_prefix).map do
      #  |template|
      #    ObjectTemplate.new(:template => template.template.to_s,
      #                       :description => template.description) unless template.hidden
      #  end.compact
      #end
      #
      ## returns model templates as ObjectModelTemplate (used for printing)
      #def get_object_model_template(namespace_prefix)
      #  get_child_templates(namespace_prefix).map do
      #  |template|
      #    ObjectModelTemplate.new(:template => template.template.to_s,
      #                            :description => template.description,
      #                            :req_metadata_hash => template.req_metadata_hash) unless template.hidden
      #  end.compact
      #end
      #
      #def get_plugin_template(namespace_prefix)
      #  get_child_templates(namespace_prefix).map do
      #  |plugin|
      #    ObjectPlugin.new(:plugin => plugin.plugin.to_s,
      #                     :description => plugin.description) unless plugin.hidden
      #  end.compact
      #end

      # Checks to make sure an arg is a format that supports a noun (uuid, etc))
      def validate_arg(*arg)
        if arg.is_a? Array
          arg.each do
          |a|
            unless a != nil && (a =~ /^\{.*\}$/) == nil && a != ''
              return false
            end
          end
        else
          arg != nil && (arg =~ /^\{.*\}$/) == nil && arg != ''
        end
      end



      # Gets a selection of objects for slice
      # @param noun [String] name of the object for logging
      # @param collection [Symbol] collection for object

      def get_object(noun, collection, uuid = nil)
        logger.debug "Query #{noun} called"

        # If uuid provided just grab and return
        if uuid
          return return_objects_using_uuid(collection, uuid)
        end

        # Check if REST-driven request
        if @web_command
          # Get request filter JSON string
          @filter_json_string = @command_array.shift
          @filter_json_string = '{}' if @filter_json_string == 'null' # handles bad PUT requests
          # Check if we were passed a filter string
          if @filter_json_string != "{}" && @filter_json_string != nil
            @command = "query_with_filter"
            begin
              # Render our JSON to a Hash
              return return_objects_using_filter(JSON.parse(@filter_json_string), collection)
            rescue StandardError => e
              # We caught an error / likely JSON. We return the error text as a Slice error.
              slice_error(e.message, false)
            end
          else
            @command = "#{noun}_query_all"
            return return_objects(collection)
          end
          # Is CLI driven
        else
          return_objects(collection)
        end
      end

      # Return objects using a filter
      # @param filter [Hash] contains key/values used for filtering
      # @param collection [Symbol] collection symbol
      def return_objects_using_filter(collection, filter_hash)
        setup_data
        @data.fetch_objects_by_filter(filter_hash, collection)
      end

      # Return all objects (no filtering)
      def return_objects(collection)
        setup_data
        @data.fetch_all_objects(collection)
      end

      # Return objects using uuid
      # @param filter [Hash] contains key/values used for filtering
      # @param collection [Symbol] collection symbol
      def return_objects_using_uuid(collection, uuid)
        setup_data
        @data.fetch_object_by_uuid_pattern(collection, uuid)
      end


      # used to parse a set of name-value command-line arguments received
      # as arguments to a slice "sub-command" and return those values to the
      # caller.  If specified, the "expected_names" field can be used to restrict
      # the names parsed to just those that are expected (useful for restricting
      # the name/value pairs to just those that are "expected")
      #
      # @param [Object] expected_names  An array containing a list of field names
      # to return (in the order in which they should be returned).  Any fields not
      # in this list will result in an error being thrown by this method.
      # @return [Hash] name/value pairs parsed from the command-line
      def get_name_value_args(expected_names = nil)
        # initialize the return values (to nil) by pre-allocating an appropriately size array
        return_vals = {}
        # parse the @command_array for "name=value" pairs
        begin
          # get the check the next value in the @command_array, continue only if
          # it's a name/value pair in the format 'name=value'
          name_val = @command_array[0]
          # if we've reached the end of the @command_array, break out of the loop
          break unless name_val
          # if it's not in the format 'name=value' then break out of the loop
          match = /([^=]+)=(.*)/.match(name_val)
          break unless match
          # since we've gotten this far, go ahead and shift the first value off
          # of the @command_array (ensuring that the @last_arg and @prev_args
          # variables are up to date as we do so)
          @last_arg = @command_array.shift
          @prev_args.push(@last_arg)
          # break apart the match array into the name and value parts
          name = match[1]
          value = match[2]
          # if a list of expected names was passed into the function, then test
          # to see if this name is one of the expected names.  If it is in the list
          # of expected names, continue, otherwise thrown an error.  If no expected_names
          # list was passed in or if the value that was passed in has a zero length,
          # then any name will be accepted (and any corresponding name/value pair will
          # be returned)
          idx = (expected_names && expected_names.size > 0 ? expected_names.index(name) : -1)
          raise ProjectRazor::Error::Slice::SliceCommandParsingFailed,
                "unrecognized field with name #{name}; valid values are #{expected_names.inspect}" unless idx
          # and add this name/value pair to the return_vals Hash map
          return_vals[name] = value
        end while @command_array.size > 0     # continue as long as there are more arguments to parse
        return return_vals
      end

      # returns the next argument from the @command_array (ensuring that the @last_arg and @prev_args
      # instance variables are kept consistent as it does so)
      def get_next_arg
        return_val = @command_array.shift
        @last_arg = return_val
        @prev_args.push(return_val)
        return_val
      end

      def print_object_details_cli(obj)
        obj.instance_variables.each do
        |iv|
          unless iv.to_s.start_with?("@_")
            key = iv.to_s.sub("@", "")
            print "#{key}: "
            print "#{obj.instance_variable_get(iv)}  ".green
          end
        end
        print "\n"
      end

      def print_model_configs(model_array)
        unless @web_command
          puts "Model Configs:"
          unless @verbose
            model_array.each do |model|
              print "   Label: " + "#{model.label}".yellow
              print "  Type: " + "#{model.name}".yellow
              print "  Description: " + "#{model.description}".yellow
              print "\n  Model UUID: " + "#{model.uuid}".yellow
              print "  Image UUID: " + "#{model.image_uuid}".yellow if model.instance_variable_get(:@image_uuid) != nil
              print "\n\n"
            end
          else
            model_array.each { |model| print_object_details_cli(model) }
          end
        else
          model_array = model_array.collect { |model| model.to_hash }
          slice_success(model_array, false)
        end
      end

      def print_model_templates(templates_array)
        if @web_command
          templates_array = templates_array.collect { |template| template.to_hash }
          slice_success(templates_array, false)
        else
          puts "Valid Model Templates:"
          if @verbose
            templates_array.each { |template| print_object_details_cli(template) }
          else
            templates_array.each { |template| puts "\t#{template.name} ".yellow + " :  #{template.description}" }
          end
        end
      end

      # Handles printing of image details to CLI
      # @param [Array] images_array
      def print_images(images_array)
        unless @web_command
          puts "Images:"

          unless @verbose
            images_array.each do
            |image|
              image.print_image_info(@data.config.image_svc_path)
              print "\n"
            end
          else
            images_array.each do
            |image|
              image.instance_variables.each do
              |iv|
                unless iv.to_s.start_with?("@_")
                  key = iv.to_s.sub("@", "")
                  print "#{key}: "
                  print "#{image.instance_variable_get(iv)}  ".green
                end
              end
              print "\n"
            end
          end
        else
          images_array = images_array.collect { |image| image.to_hash }
          slice_success(images_array, false)
        end
      end

      # Handles printing of node details to CLI or REST
      # @param [Hash] node_array
      def print_node(node_array)
        unless @web_command
          puts "Nodes:"

          unless @verbose
            node_array.each do
            |node|
              print "\tuuid: "
              print "#{node.uuid}  ".green
              print "last state: "
              print "#{node.last_state}  ".green
              print "name: " unless node.name == nil
              print "#{node.name}  ".green unless node.name == nil
              print "\n"
            end
          else
            node_array.each do
            |node|
              node.instance_variables.each do
              |iv|
                unless iv.to_s.start_with?("@_")
                  key = iv.to_s.sub("@", "")
                  print "#{key}: "
                  print "#{node.instance_variable_get(iv)}  ".green
                end
              end
              print "\n"
            end
          end
        else
          node_array = node_array.collect { |node| node.to_hash }
          slice_success(node_array,false)
        end
      end

      #def print_policy_bound_log(bound_policy)
      #  unless @web_command
      #    puts "Bound policy log for Node(#{bound_policy.node_uuid}):"
      #
      #    unless @verbose
      #      print "\t" + "(Model call) (Action) | (Original state) => (New state) | (Time)\n".red_on_black
      #      bound_policy.model.log.each do
      #      |log_item|
      #        print "\t#{log_item["method"]}##{log_item["action"]} | ".white_on_black
      #        print "#{log_item["old_state"]} => #{log_item["state"]}".white_on_black
      #        print " | #{Time.at(log_item["timestamp"].to_i)}\n".white_on_black
      #      end
      #
      #    else
      #      bound_policy.model.log.each do
      #      |log_item|
      #        log_item.instance_variables.each do
      #        |iv|
      #          unless iv.to_s.start_with?("@_")
      #            key = iv.to_s.sub("@", "")
      #            print "#{key}: "
      #            print "#{log_item.instance_variable_get(iv)}  ".green
      #          end
      #        end
      #        print "\n"
      #      end
      #    end
      #  else
      #    slice_success(bound_policy.model.log, false)
      #  end
      #end

      def print_tag_rule_old(rule_array)
        if rule_array.respond_to?(:each)
          rule_array = rule_array.collect { |rule| rule.to_hash }
          slice_success(rule_array, false)
        else
          slice_success(rule_array.to_hash, false)
        end
      end

      def print_tag_rule(object_array)
        unless @web_command
          puts "Tag Rules:"

          unless @verbose

            print_array = []
            header = []
            line_color = :green
            header_color = :white

            object_array.each do
            |rule|
              print_array << rule.print_items
              header = rule.print_header
              line_color = rule.line_color
              header_color = rule.header_color
            end

            print_array.unshift header if header != []
            print_table(print_array, line_color, header_color)
          else
            object_array.each do
            |rule|
              rule.instance_variables.each do
              |iv|
                unless iv.to_s.start_with?("@_")
                  key = iv.to_s.sub("@", "")
                  print "#{key}: "
                  print "#{rule.instance_variable_get(iv)}  ".green
                end
              end
              print "\n"
            end
          end
        else
          object_array = object_array.collect { |rule| rule.to_hash }
          slice_success(object_array, false)
        end
      end

      def print_tag_matcher(object_array)
        unless @web_command
          puts "\t\tTag Matchers:"

          unless @verbose
            object_array.each do
            |matcher|
              print "   Key: " + "#{matcher.key}".yellow
              print "  Compare: " + "#{matcher.compare}".yellow
              print "  Value: " + "#{matcher.value}".yellow
              print "  Inverse: " + "#{matcher.inverse}".yellow
              print "\n"
            end
          else
            object_array.each do
            |matcher|
              matcher.instance_variables.each do
              |iv|
                unless iv.to_s.start_with?("@_")
                  key = iv.to_s.sub("@", "")
                  print "#{key}: "
                  print "#{matcher.instance_variable_get(iv)}  ".green
                end
              end
              print "\n"
            end
          end
        else
          object_array = object_array.collect { |matcher| matcher.to_hash }
          slice_success(object_array, false)
        end
      end

      def print_object_array(object_array, title = nil, options = {})
        # This is for backwards compatibility
        title = options[:title] unless title
        unless @web_command
          puts title if title
          unless object_array.count > 0
            puts "< none >".red
          end
          unless @verbose
            print_array = []
            header = []
            line_colors = []
            header_color = :white

            if object_array.count == 1 && options[:style] != :table
              puts print_single_item(object_array.first)
            else
              object_array.each do
              |obj|
                print_array << obj.print_items
                header = obj.print_header
                line_colors << obj.line_color
                header_color = obj.header_color
              end
              # If we have more than one item we use table view, otherwise use item view
              print_array.unshift header if header != []
              puts print_table(print_array, line_colors, header_color)
            end
          else
            object_array.each do
            |obj|
              obj.instance_variables.each do
              |iv|
                unless iv.to_s.start_with?("@_")
                  key = iv.to_s.sub("@", "")
                  print "#{key}: "
                  print "#{obj.instance_variable_get(iv)}  ".green
                end
              end
              print "\n"
            end
          end
        else
          if @uri_root
            object_array = object_array.collect do |object|
              if object.is_template
                object.to_hash
              else
                obj_web = object.to_hash
                obj_web.select! { |k, v| ["@uuid", "@classname"].include?(k) } unless object_array.count == 1
                add_uri_to_object_hash(obj_web)
                iterate_obj(obj_web)
                obj_web
              end
            end
          else
            object_array = object_array.collect { |object| object.to_hash }
          end

          slice_success(object_array, options)
        end
      end

      def iterate_obj(obj_hash)
        obj_hash.each do
          |k,v|
          if obj_hash[k].class == Array
            obj_hash[k].each do
              |item|
              if item.class == Hash
                add_uri_to_object_hash(item)
              end
            end
          end
        end
        obj_hash
      end

      def add_uri_to_object_hash(object_hash)
        noun = get_noun(object_hash["@classname"])
        object_hash["@uri"] = "#{@uri_root}#{noun}/#{object_hash["@uuid"]}" if noun
        object_hash
      end

      def print_single_item(obj)
        print_array = []
        header = []
        line_color = []
        print_output = ""
        header_color = :white

        if obj.respond_to?(:print_item) && obj.respond_to?(:print_item_header)
          print_array = obj.print_item
          header = obj.print_item_header
        else
          print_array = obj.print_items
          header = obj.print_header
        end
        line_color = obj.line_color
        header_color = obj.header_color
        print_array.each_with_index do
        |val, index|
          if header_color
            print_output << " " + "#{header[index]}".send(header_color)
          else
            print_output << " " + "#{header[index]}"
          end
          print_output << " => "
          if line_color
            print_output << " " + "#{val}".send(line_color) + "\n"
          else
            print_output << " " + "#{val}" + "\n"
          end

        end
        print_output
      end

      def print_table(print_array, line_colors, header_color)
        table = ""
        print_array.each_with_index do
        |line, li|
          line_string = ""
          line.each_with_index do
          |col, ci|
            max_col = print_array.collect {|x| x[ci].length}.max
            if li == 0
              if header_color
                line_string << "#{col.center(max_col)}  ".send(header_color)
              else
                line_string << "#{col.center(max_col)}  "
              end
            else
              if line_colors[li-1]
                line_string << "#{col.ljust(max_col)}  ".send(line_colors[li-1])
              else
                line_string << "#{col.ljust(max_col)}  "
              end
            end
          end
          table << line_string + "\n"
        end
        table
      end
    end
  end
end

