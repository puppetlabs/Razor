# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved

require "json"



module ProjectRazor
  module Slice
    # ProjectRazor Tag Slice
    # Tag
    # @author Nicholas Weaver
    class Tagmatcher < ProjectRazor::Slice::Base

      # init
      # @param [Array] args
      def initialize(args)
        super(args)
        # Define your commands and help text
        @slice_commands = {:default => "must_have_get",
                           :get => "get_tag_matcher",
                           :add => "add_tag_matcher",
                           :remove => "remove_tag_matcher",
        }
        @slice_commands_help = {:get => "tagmatcher".red + " [add|remove|get] (tag rule uuid)".blue,
                                :add => "tagmatcher".red + " add (tag rule uuid) (key) (value) [equal|like]".blue + " {inverse}".yellow,
                                :remove => "tagmatcher".red + " remove (tag rule uuid) (tag matcher uuid)".blue}
        @slice_name = "Tagmatcher"
      end

      def must_have_get
        slice_error("InvalidCommand")
      end

      def get_tag_matcher
        @command = :get
        uuid = validate_tag_rule
        unless uuid
          return
        end

        print_object_array [@tag_rule], "Tag Rule" unless @web_command
        print_object_array @tag_rule.tag_matchers, "Tag Matchers"
      end

      def add_tag_matcher
        @command = :add
        uuid = validate_tag_rule
        unless uuid
          return
        end

        if @web_command


        else
          key = @command_array.shift
          value = @command_array.shift
          compare = @command_array.shift
          inverse = @command_array.shift

          unless validate_arg(key)
            slice_error("MissingKey")
            return
          end
          unless validate_arg(value)
            slice_error("MissingValue")
            return
          end
          unless validate_arg(compare)
            slice_error("MissingCompare")
            return
          end
          unless inverse == nil
            unless inverse == "inverse"
              slice_error("InvalidInverseStatement")
              return
            end
          end

          unless compare == "equal" || compare == "like"
            slice_error("InvalidCompare")
            return
          end

          inverse = "true" if inverse
          inverse = "false" unless inverse

          if @tag_rule.add_tag_matcher(key, value, compare, inverse)
            if @tag_rule.update_self
              @command_array.unshift(@tag_rule.uuid)
              get_tag_matcher
            else
              slice_error("CouldNotUpdateTagRule")
              return
            end
          else
            slice_error("CouldNotAddMatcher")
            return
          end




        end



      end

      def remove_tag_matcher
        @command = :get
        uuid = validate_tag_rule
        unless uuid
          return
        end

        tag_matcher_uuid = @command_array.shift

        unless validate_arg(tag_matcher_uuid)
          slice_error("MustProvideTagMatcherUUID")
          @command_array.unshift(uuid)
          return get_tag_matcher
        end

        tag_matcher = nil
        @tag_rule.tag_matchers.each do
          |tm|
          tag_matcher = tm if tm.uuid == tag_matcher_uuid
        end

        unless tag_matcher
          slice_error("InvalidTagMatcherUUID")
          @command_array.unshift(uuid)
          return get_tag_matcher
        end

        @tag_rule.tag_matchers.delete(tag_matcher)
        if @tag_rule.update_self
        slice_success("TagMatcherRemoved")
        @command_array.unshift(uuid)
        return get_tag_matcher
        else
          slice_error("CouldNotUpdateTagRule")
          return
        end
      end

      def validate_tag_rule
        uuid = @command_array.shift

        unless validate_arg(uuid)
          slice_error("MustProvideTagRuleUUID")
          return false
        end

        setup_data
        @tag_rule = @data.fetch_object_by_uuid(:tag, uuid)
        unless @tag_rule
          slice_error("CannotFindTagRule")
          print_object_array get_object("tag_rules", :tag), "Valid Tag Rules" unless @web_command
          return false
        end
        uuid
      end




    end
  end
end