module ProjectRazor
  module Filtering

    # Uses a provided Filter Hash to match against an Object hash
    # @param filter_hash [Hash]
    # @param object_hash [Hash]
    def check_filter_vs_hash(filter_hash, object_hash, loop = false)
      object_hash = sanitize_hash(object_hash)
      filter_hash = sanitize_hash(filter_hash)
      # Iterate over each key/value checking if there is a match within the object_hash level
      # if we run into a key/value that is a hash we check for a matching hash and call this same method
      filter_hash.each_key do
      |filter_key|
        logger.debug "looking for key: #{filter_key}"
        # Find a matching key / return false if there is none

        object_key = find_key_match(filter_key, object_hash)
        logger.debug "not found: #{filter_key}" if object_key == nil
        return false if object_key == nil
        logger.debug "found: #{object_key} #{object_hash.class.to_s}"

        # If our keys match and the values are Hashes then iterate again catching the return and
        # passing if it is False
        if filter_hash[filter_key].class == Hash && object_hash[object_key].class == Hash
          # Check deeper, setting the loop value to prevent changing the key prefix
          logger.debug "both values are hash, going deeper"
          return false if !check_filter_vs_hash(filter_hash[filter_key], object_hash[object_key], true)
        else

          # Eval if our keys (one of which isn't a Hash) match
          # We accept either exact or Regex match
          # If the filter key value is empty we are ok with it just existing and return true

          if filter_hash[filter_key] != ""
            begin
              logger.debug "Looking for match: #{filter_hash[filter_key]} : #{object_hash[object_key]}"
              if filter_hash[filter_key].class == Hash || object_hash[object_key].class == Hash
                logger.debug "one of these is a hash when the other isn't"
                return false
              end

              # If the filter_hash[filter_key] value is a String and it starts with 'regex:'
              # then use a regular expression for comparison; else compare as literals
              if filter_hash[filter_key].class == String && filter_hash[filter_key].start_with?('regex:')
                regex_key = filter_hash[filter_key].sub(/^regex:/,"")
                if Regexp.new(regex_key).match(object_hash[object_key]) == nil
                  logger.debug "no match - regex"
                  return false
                end
              else
                if filter_hash[filter_key] != object_hash[object_key]
                  logger.debug "no match - literal"
                  return false
                end
              end
            rescue => e
              # Error encountered - likely nil or Hash -> String / return false as this means key != key
              logger.error e.message
              return false
            end
          end
        end
      end
      logger.debug "match found"
      true
    end

    def sanitize_hash(in_hash)
      new_hash = {}
      in_hash.each_key do
        |k|
        new_hash[k.sub(/^@/,"")] = in_hash[k]
      end
      new_hash
    end

    def find_key_match(filter_key, object_hash)
      object_hash.each_key do
      |object_key|
        return object_key if filter_key == object_key
      end
      nil
    end

  end
end

