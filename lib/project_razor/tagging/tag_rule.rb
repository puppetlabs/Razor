# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved

module ProjectRazor
  module Tagging
    class TagRule < ProjectRazor::Object
      include(ProjectRazor::Logging)

      attr_accessor :name
      attr_accessor :tag
      attr_accessor :tag_matchers

      # TODO - method for setting tags that removes duplicates

      def initialize(hash)
        super()
        @name = "Tag Rule: #{@uuid}"
        @tag = ""
        @tag_matchers = []
        @_collection = :tag

        from_hash(hash) unless hash == nil
        tag_matcher_from_hash unless hash == nil
      end

      def check_tag_rule(attributes_hash)
        logger.debug "Checking tag rule"
        logger.warn "No tag matchers for tag rule" if @tag_matchers.count == 0
        return false if @tag_matchers.count == 0

        @tag_matchers.each do
        |tag_matcher|
          logger.debug "Tag Matcher key: #{tag_matcher.key}"

          # For each tag matcher we go through the attributes_hash and look for matching key and matching value

          # If key isn't found we return false
          if attributes_hash[tag_matcher.key] == nil && tag_matcher.inverse == false # we don't care if matcher is inverse
            logger.debug "Key #{tag_matcher.key} does not exist"
            return false
          end
          # If key/value doesn't match we return false
          unless tag_matcher.check_for_match(attributes_hash[tag_matcher.key])
            logger.debug "Key #{tag_matcher.key} does not match"
            return false
          end
        end

        # Otherwise we return true
        true
      end

      def add_tag_matcher(key, value, compare, inverse)
        logger.debug "New tag matcher: '#{key}' #{compare} '#{value}' inverse:#{inverse.to_s}"
        if key.class == String && value.class == String
          if compare.to_s == "equal" || compare.to_s == "like"
            if inverse == "true" || inverse == "false"


              tag_matcher = ProjectRazor::Tagging::TagMatcher.new({"@key" => key,
                                                                   "@value" => value,
                                                                   "@compare" => compare,
                                                                   "@inverse" => inverse})
              if tag_matcher.class == ProjectRazor::Tagging::TagMatcher
                logger.debug "New tag matcher added successfully"
                @tag_matchers << tag_matcher
                return true
              end
            end
          end
        end
        false
      end

      def remove_tag_matcher(uuid)
        tag_matcher_from_hash
        tag_matchers.delete_if {|tag_matcher| tag_matcher.uuid == uuid}
      end

      def tag_matcher_from_hash
        new_array = []
        @tag_matchers.each do
        |tag_matcher_hash|
          if tag_matcher_hash.class == Hash || tag_matcher_hash.class == BSON::OrderedHash # change this to check descendant of Hash
            new_array << ProjectRazor::Tagging::TagMatcher.new(tag_matcher_hash)
          else
            new_array << tag_matcher_hash
          end
        end

        @tag_matchers = new_array
      end


      # Override from_hash to convert our tag matchers if they exist
      def from_hash(hash)
        super(hash)
        new_tag_matchers_array = []
        @tag_matchers.each do
        |tag_matcher|
          if tag_matcher.class != ProjectRazor::Tagging::TagMatcher
            new_tag_matchers_array << ProjectRazor::Tagging::TagMatcher.new(tag_matcher)
          else
            new_tag_matchers_array << tag_matcher
          end
        end
      end

      def to_hash
        @tag_matchers = @tag_matchers.each {|tm| tm.to_hash}
        super
      end

      def print_header
        return "Name", "Tags", "UUID"
      end

      def print_items
        return @name, @tag.join(","), @uuid
      end

      def line_color
        :white_on_blue
      end

      def header_color
        :blue_on_white
      end


    end
  end
end