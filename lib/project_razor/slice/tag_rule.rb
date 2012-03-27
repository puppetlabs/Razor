# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved

require "json"

module ProjectRazor
  module Slice
    # ProjectRazor Tag Slice
    # Tag
    # @author Nicholas Weaver
    class Tagrule < ProjectRazor::Slice::Base

      # init
      # @param [Array] args
      def initialize(args)
        super(args)
        # Define your commands and help text
        @slice_commands = {:default => "get_tag",
                           :get => "get_tag",
                           :add => "add_tag",
                           :remove => "remove_tag",
        }
        @slice_commands_help = {:rule => "tag rule".red + "[add|remove|get]".blue,
                                :matcher => "tag matcher".red + " (tag rule uuid) [add|remove|get]".blue,
                                "add_tag_rule" => "tag rule add ".red + "(name) (tag{,tag,tag})".blue,
                                "remove_tag" => "tagrule remove ".red + "[(uuid)|all]".blue}
        @slice_name = "Tagrule"
      end



      def remove_tag
        @command = "remove_tag"
        uuid = @command_array.shift

        if uuid == "all"
          setup_data
          @data.delete_all_objects(:tag)
          slice_success("AllTagRulesRemoved")
          return
        end

        unless validate_arg(uuid)
          slice_error("MissingUUID")
          print_object_array get_object("tag_rules", :tag), "Existing Tag Rules" unless @web_command
          return
        end

        setup_data
        tag_rule = @data.fetch_object_by_uuid(:tag, uuid)

        unless tag_rule !=  nil
          slice_error("InvalidUUID")
          print_object_array get_object("tag_rules", :tag), "Existing Tag Rules" unless @web_command
          return
        end

        if @data.delete_object(tag_rule)
          slice_success("TagRuleDeleted")
        else
          slice_error("CouldNotDeleteTagRule")
        end

      end

      def get_tag
        uuid = @command_array.shift
        @command = :get

        if validate_arg(uuid)
          setup_data
          tag_rule = @data.fetch_object_by_uuid(:tag, uuid)

          unless tag_rule
            slice_error("InvalidUUID")
            print_object_array get_object("tag_rule", :tag), "Valid Tag Rules:" unless @web_command
            return
          end


          print_object_array [tag_rule], nil
          return
        end





        print_object_array get_object("tag_rule", :tag), "Tag Rules:"
      end

      def add_tag
        if @web_command
          add_tag_rule_web
        else
          add_tag_cli
        end
      end

      def add_tag_cli
        @command = "add_tag_rule"
        name = @command_array.shift

        unless validate_arg(name)
          slice_error("InvalidName")
          return
        end


        tags = @command_array.shift
        unless tags != nil
          slice_error("MustProvideAtLeastOneTag")
          return
        end
        tags_array = tags.split(",")
        unless tags_array.count > 0
          slice_error("MustProvideAtLeastOneTag")
          return
        end

        new_tag_rule = ProjectRazor::Tagging::TagRule.new({})
        new_tag_rule.name = name
        new_tag_rule.tag = tags_array
        new_tag_rule.tag_matchers = []

        setup_data
        new_tag_rule = @data.persist_object(new_tag_rule)
        print_object_array [new_tag_rule], "Added Tag Rule:"
        slice_success("TagRuleAdded")
      end



      def add_tag_web
        @command = "add_tag_rule"
        json_string = @command_array.shift
        if json_string != "{}" && json_string != nil
          begin
            post_hash = JSON.parse(json_string)
            if post_hash["@name"] != nil && post_hash["@tag"] != nil && post_hash["@tag_matchers"] != nil
              new_tag_rule = ProjectRazor::Tagging::TagRule.new(post_hash)
              setup_data
              if @data.persist_object(new_tag_rule) != nil
                print_tag_rule [new_tag_rule]
              else
                slice_error("CouldNotCreateTagRule", false)
              end
            else
              slice_error("MissingProperties", false)
            end
          rescue => e
            slice_error(e.message, false)
          end

        else
          slice_error("MissingAttributes", false)
        end
      end

      def remove_tag_rule
        @command = "remove_tag_rule"
        tag_rule_uuid = @command_array.shift

        unless validate_arg(tag_rule_uuid)
          slice_error("MissingUUID")
          print_object_array get_object("tag_rules", :tag), "Existing Tag Rules" unless @web_command
          return
        end

        setup_data
        tag_rule = @data.fetch_object_by_uuid(:tag, tag_rule_uuid)
        unless tag_rule != nil
          slice_error("CannotFindTagRule")
          print_object_array get_object("tag_rules", :tag), "Existing Tag Rules" unless @web_command
          return
        end

        if @data.delete_object_by_uuid(:tag, tag_rule.uuid)
          slice_success("TagRuleDeleted", false)
        else
          slice_error("TagRuleCouldNotBeDeleted", false)
        end

      end







      def matcher_call
        @command_query_string = @command_array.shift
        case @command_query_string

          when "add"
            add_tag_matcher
          when "remove"
            remove_tag_matcher
          else
            @command = "get_tag_matcher"
            tag_rule = get_tag_rule_by_uuid(@command_query_string)
            slice_success(tag_rule.to_hash, false) unless !tag_rule
        end
      end

      def add_tag_matcher
        @command = "add_tag_matcher"
        # First make sure we have a valid rule
        tag_rule = get_tag_rule_by_uuid(@command_array.shift)
        return if !tag_rule


        begin
          json_string = @command_array.shift
          if json_string != nil && (json_string =~ /^\{.*\}$/) != nil && json_string != ''
            tag_matcher = ProjectRazor::Tagging::TagMatcher.new(JSON.parse(json_string))
            if tag_rule.add_tag_matcher(tag_matcher.key,tag_matcher.value,tag_matcher.compare,tag_matcher.inverse)
              if tag_rule.update_self
                slice_success(tag_rule.to_hash, false)
              else
                slice_error("CouldNotUpdateTagRule", false)
              end
            else
              slice_error("CouldNotAddTagMatcherToRule", false)
            end
          else
            slice_error("MissingTagMatcherProperties", false)
          end
        rescue => e
          logger.error e.message
          slice_error(e.message, false)
        end
      end


      def remove_tag_matcher
        @command = "add_tag_matcher"
        # First make sure we have a valid rule
        tag_rule = get_tag_rule_by_uuid(@command_array.shift)
        return if !tag_rule


        begin
          uuid = @command_array.shift
          if uuid != nil && (uuid =~ /^\{.*\}$/) == nil && uuid != ''
            if tag_rule.remove_tag_matcher(uuid)
              slice_success(tag_rule.to_hash, false)
            else
              slice_error("TagMatcherNotFound", false)
            end
          else
            slice_error("InvalidTagMatcherUUID", false)
          end
        rescue => e
          logger.error e.message
          slice_error(e.message, false)
        end
      end

      def get_tag_rule_by_uuid(uuid)
        if uuid != nil && (uuid =~ /^\{.*\}$/) == nil && uuid != ''
          @command_array.unshift('{"@uuid":"' + uuid +'"}')
          tag_rules = get_object("tag_rule", :tag)
          tag_rules.each do
          |tag_rule|
            if tag_rule.uuid == uuid
              return tag_rule
            end
          end
          slice_success("TagRuleNotFound", false)
          false
        else
          slice_error("NoTagRuleUUIDProvided", false)
          false
        end
      end
    end
  end
end