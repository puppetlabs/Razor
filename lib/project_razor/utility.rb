# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved

require "yaml"
require "bson"

# ProjectRazor::Utility namespace
# @author Nicholas Weaver
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

    # Iterates and converts BSON:OrderedHash back to vanilla hash / MongoDB specific
    # @param bson_hash [Hash]
    # @return [Hash]
    def bson_to_hash(bson_hash)
      new_hash = {}
      bson_hash.each_key do
      |k|
        if bson_hash[k].class == BSON::OrderedHash
          new_hash[k] = bson_to_hash(bson_hash[k])
        else
          new_hash[k] = bson_hash[k]
        end
      end
      new_hash
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
            self.instance_variable_set(key, Object::full_const_get(hash[key]["@classname"]).new(hash[key])) unless key.to_s.start_with?("_")
          else
            self.instance_variable_set(key, value) unless key.to_s.start_with?("_")
          end
        else
          self.instance_variable_set(key, value) unless key.to_s.start_with?("_")
        end
      end
    end

    # Validates that all instance variables for the object are not nil
    def validate_instance_vars
      flag = true
      self.instance_variables.each { |iv| flag = false if (self.instance_variable_get(iv) == nil && !iv.to_s.start_with?("@_")) }
      flag
    end

    # Returns the version number as [String] from ./conf/version
    # @return [String]
    def get_razor_version
      file = File.open("#{$razor_root}/conf/version", "rb")
      version = file.read
      file.close
      version
    end

    def get_child_types(namespace_prefix)
      temp_hash = {}
      ObjectSpace.each_object do
      |object_class|

        if object_class.to_s.start_with?(namespace_prefix) && object_class.to_s != namespace_prefix
          temp_hash[object_class.to_s] = object_class.to_s.sub(namespace_prefix,"").strip
        end
      end
      object_array = {}
      temp_hash.each_value {|x| object_array[x] = x}
      object_array.each_value.collect {|x| x}.collect {|x| Object::full_const_get(namespace_prefix + x).new({})}


    end
  end
end