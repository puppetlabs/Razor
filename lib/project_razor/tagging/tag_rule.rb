
module ProjectRazor
  module Tagging
    class TagRule < ProjectRazor::Object
      include(ProjectRazor::Logging)
      attr_accessor :name
      attr_accessor :tag
      attr_accessor :tag_matchers
      def initialize(hash)
        super()
        @name = "Tag Rule: #{@uuid}"
        @tag = ""
        @tag_matchers = []
        @_namespace = :tag
        @noun = "tag"

        from_hash(hash) unless hash == nil
        tag_matcher_from_hash unless hash == nil
      end

      # This method is called by the engine on tagging
      # It allows us to parse the tag metaname vars and reply back with a correct tag
      def get_tag(meta)
        sanitize_tag parse_tag_metadata_vars(meta)
      end

      # Remove symbols, whitespace, junk from tags
      # tags are alphanumeric mostly (with the exception of '%, =, -, _')
      def sanitize_tag(in_tag)
        in_tag.gsub(/[^\w%=\-\\+]+/,"")
      end

      # Used for parsing tag metanaming vars
      def parse_tag_metadata_vars(meta)
        begin
          return tag unless meta
          new_tag = tag
          # Direct value metaname var
          # pattern:  %V=key_name-%
          # Where 'key_name' is the key name from the metadata hash
          # directly inserts the value or nothing if nil
          direct_value = new_tag.scan(/%V=[\w ]*-%/)
          direct_value.map! do |dv|
            {
                :var => dv,
                :key_name => dv.gsub(/%V=|-%/, ""),
                :value => meta[dv.gsub(/%V=|-%/, "")]
            }
          end
          direct_value.each do
          |dv|
            dv[:value] ||= ""
            new_tag = new_tag.gsub(dv[:var].to_s,dv[:value].to_s)
          end


          # Selected value metaname var
          # pattern:  %R=selection_pattern:key_name-%
          # Where 'key_name' is the key name from the metadata hash
          # Where 'selection_pattern' is a Regex string for selecting a portion of the value from the key name in the metadata hash
          # directly inserts the value or nothing if nil
          selected_value = new_tag.scan(/%R=.+:[\w]+-%/)
          selected_value.map! do |dv|
            {
                :var => dv,
                :var_string => dv.gsub(/%R=|-%/, ""),
                :key_name => dv.gsub(/%R=|-%/, "").split(":")[1],
                :pattern => Regexp.new(dv.gsub(/%R=|-%/, "").split(":").first)
            }
          end

          selected_value.each do
          |sv|
            if sv[:pattern] && sv[:key_name]
              sv[:value] = sv[:pattern].match(meta[sv[:key_name]]).to_s
            end
            sv[:value] ||= ""
            new_tag = new_tag.gsub(sv[:var].to_s,sv[:value].to_s)
          end
        rescue => e
          logger.error "ERROR: #{e}"
          tag
        end
        new_tag
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

      def add_tag_matcher(options = {})
        key = options[:key]
        value = options[:value]
        compare = options[:compare]
        inverse = options[:inverse]
        logger.debug "New tag matcher: '#{key}' #{compare} '#{value}' inverse:#{inverse.to_s}"
        if key.class == String && value.class == String
          if compare.to_s == "equal" || compare.to_s == "like"
            if inverse == "true" || inverse == "false"


              tag_matcher = ProjectRazor::Tagging::TagMatcher.new({"@key" => key,
                                                                   "@value" => value,
                                                                   "@compare" => compare,
                                                                   "@inverse" => inverse},
                                                                  @uuid)
              if tag_matcher.class == ProjectRazor::Tagging::TagMatcher
                logger.debug "New tag matcher added successfully"
                @tag_matchers << tag_matcher
                return tag_matcher
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
            new_array << ProjectRazor::Tagging::TagMatcher.new(tag_matcher_hash, @uuid)
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
            new_tag_matchers_array << ProjectRazor::Tagging::TagMatcher.new(tag_matcher, @uuid)
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
        return "Name", "Tags", "UUID", "Matchers [count]"
      end

      def print_items
        return @name, @tag, @uuid, @tag_matchers.count.to_s
      end

      def print_item_header
        ["Name", "Tags", "UUID", "Matcher"]
      end

      def print_item

        [@name, @tag, @uuid, tag_matcher_print]
      end

      def line_color
        :white_on_black
      end

      def header_color
        :red_on_black
      end

      def tag_matcher_print
        #return @tag_matchers.inspect
        if @tag_matchers.count > 0
          print_string = "\n"
          @tag_matchers.each do
          |tm|
            tm = ProjectRazor::Tagging::TagMatcher.new(tm, @uuid) unless tm.class == ProjectRazor::Tagging::TagMatcher
            print_string << "\t#{tm.uuid} - '#{tm.key}' (#{tm.inverse == "true" ? "NOT " : ""}#{tm.compare}) '#{tm.value}'\n"
          end
          print_string
        else
          "<none>"
        end
      end


    end
  end
end
