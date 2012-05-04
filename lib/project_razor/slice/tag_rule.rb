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
        @hidden = false
        # Define your commands and help text
        @slice_commands = {:default => "get_tag",
                           :get => "get_tag",
                           :add => "add_tag",
                           :remove => "remove_tag",
        }
        @slice_commands_help = {:default => "tagrule".red + "[add|remove|get]".blue,
                                :get => "tagrule".red + "[add|remove|get]".blue,
                                "add_tag" => "tagrule add ".red + "(name) (tag{,tag,tag})".blue,
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




        @command_array.unshift uuid
        print_object_array get_object("tag_rule", :tag), "Tag Rules:"
      end

      def add_tag
        if @web_command
          add_tag_web
        else
          add_tag_cli
        end
      end

      def add_tag_cli
        @command = "add_tag"
        name = @command_array.shift

        unless validate_arg(name)
          slice_error("InvalidName")
          return
        end


        tag = @command_array.shift
        unless tag != nil
          slice_error("MustProvideTag")
          return
        end

        unless validate_arg(tag)
          slice_error("TagInvalid")
          return
        end

        new_tag_rule = ProjectRazor::Tagging::TagRule.new({})
        new_tag_rule.name = name
        new_tag_rule.tag = tag.to_s
        new_tag_rule.tag_matchers = []

        setup_data
        new_tag_rule = @data.persist_object(new_tag_rule)
        print_object_array [new_tag_rule], "Added Tag Rule:"
        slice_success("TagRuleAdded")
      end



      def add_tag_web
        @command = "add_tag"
        json_string = @command_array.shift
        if json_string != "{}" && json_string != nil
          begin
            post_hash = JSON.parse(json_string)
            if post_hash["@name"] != nil && post_hash["@tag"] != nil
              name = post_hash["@name"]

              unless validate_arg(name)
                slice_error("InvalidName")
                return
              end

              new_tag_rule = ProjectRazor::Tagging::TagRule.new(post_hash)



              new_tag_rule.tag_matchers = [] unless new_tag_rule.tag_matchers


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







    end
  end
end