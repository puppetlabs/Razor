
require "yaml"
require "bson"

# ProjectRazor::Utility namespace
module ProjectRazor
  module Utility

    # Returns a hash array of instance variable symbol and instance variable value for self
    # will ignore instance variables that start with '_'
    def to_hash
      hash = {}
      self.instance_variables.each do |iv|
        if !iv.to_s.start_with?("@_") && self.instance_variable_get(iv).class != Logger
          if self.instance_variable_get(iv).class == Array
            new_array = []
            self.instance_variable_get(iv).each do
            |val|
              if val.respond_to?(:to_hash)
                new_array << val.to_hash
              else
                new_array << val
              end
            end
            hash[iv.to_s] = new_array
          else
            if self.instance_variable_get(iv).respond_to?(:to_hash)
              hash[iv.to_s] = self.instance_variable_get(iv).to_hash
            else
              hash[iv.to_s] = self.instance_variable_get(iv)
            end
          end
        end
      end
      hash
    end

    # Sets instance variables
    # will not include any that start with "_" (Mongo specific)
    # @param [Hash] hash
    def from_hash(hash)
      hash.each_pair do |key, value|

        # We need to catch hashes representing child objects
        # If the hash key:value is a of a Hash/BSON:Ordered hash
        if hash[key].class == Hash || hash[key].class == BSON::OrderedHash
          # If we have a classname we know we need to return to an object
          if hash[key]["@classname"]
            self.instance_variable_set(key, ::Object::full_const_get(hash[key]["@classname"]).new(hash[key])) unless key.to_s.start_with?("_")
          else
            self.instance_variable_set(key, value) unless key.to_s.start_with?("_")
          end
        else
          self.instance_variable_set(key, value) unless key.to_s.start_with?("_")
        end
      end
    end

    def new_object_from_template_name(namespace_prefix, object_template_name)
      get_child_types(namespace_prefix).each do
      |template|
        return template if template.template.to_s == object_template_name
      end
      nil
    end

    alias :new_object_from_type_name :new_object_from_template_name


    def sanitize_hash(in_hash)
      in_hash.inject({}) {|h, (k, v)| h[k.sub(/^@/, '')] = v; h }
    end

    def self.encode_symbols_in_hash(obj)
      case obj
      when Hash
        encoded = Hash.new
        obj.each_pair { |key, value| encoded[key] = encode_symbols_in_hash(value) }
        encoded
      when Array
        obj.map { |item| encode_symbols_in_hash(item) }
      when Symbol
        ":#{obj}"
      else
        obj
      end
    end

    def self.decode_symbols_in_hash(obj)
      case obj
      when Hash
        decoded = Hash.new
        obj.each_pair { |key, value| decoded[key] = decode_symbols_in_hash(value) }
        decoded
      when Array
        obj.map { |item| decode_symbols_in_hash(item) }
      when /^:/
        obj.sub(/^:/, '').to_sym
      else
        obj
      end
    end
  end
end
