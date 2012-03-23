# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved

require "json"

module ProjectRazor
  module SliceUtil
    module Common


      # Gets a selection of objects for slice
      # @param noun [String] name of the object for logging
      # @param collection [Symbol] collection for object

      def get_object(noun, collection)
        logger.debug "Query #{noun} called"

        # Check if REST-driven request
        if @web_command

          # Get request filter JSON string
          @filter_json_string = @command_array.shift
          # Check if we were passed a filter string
          if @filter_json_string != "{}" && @filter_json_string != nil
            @command = "query_with_filter"
            begin
              # Render our JSON to a Hash
              return return_object_using_filter(JSON.parse(@filter_json_string), collection)
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
      def return_object_using_filter(collection, filter_hash)
      setup_data
        @data.fetch_objects_by_filter(filter_hash, collection)
      end

      # Return all objects (no filtering)
      def return_objects(collection)
        setup_data
        @data.fetch_all_objects(collection)
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




      ########### Common Slice Printing ###########

      def print_policy_types(types_array)
        unless @web_command
          puts "Valid Policy Types:"
          unless @verbose
            types_array.each { |type| puts "\t#{type.policy_type} ".yellow + " :  #{type.description}" }
          else
            types_array.each { |type| print_object_details_cli(type) }
          end
        else
          types_array = types_array.collect { |type| type.to_hash }
          slice_success(types_array, false)
        end
      end

      def print_model_configs(model_array)
        unless @web_command
          puts "Model Configs:"
          unless @verbose
            model_array.each do |model|
              print "   Label: " + "#{model.label}".yellow
              print "  Type: " + "#{model.name}".yellow
              print "  Description: " + "#{model.description}".yellow
              print "  UUID: " + "#{model.uuid}\n".yellow
            end
          else
            model_array.each { |model| print_object_details_cli(model) }
          end
        else
          model_array = model_array.collect { |model| model.to_hash }
          slice_success(model_array, false)
        end
      end

      def print_model_types(types_array)
        if @web_command
          types_array = types_array.collect { |type| type.to_hash }
          slice_success(types_array, false)
        else
          puts "Valid Model Types:"
          if @verbose
            types_array.each { |type| print_object_details_cli(type) }
          else
            types_array.each { |type| puts "\t#{type.name} ".yellow + " :  #{type.description}" }
          end
        end
      end


    end
  end
end
