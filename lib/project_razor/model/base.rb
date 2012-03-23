# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved


# Root ProjectRazor namespace
# @author Nicholas Weaver
module ProjectRazor
  module Model
    # Root Model object
    # @author Nicholas Weaver
    # @abstract
    class Base < ProjectRazor::Object
      attr_accessor :name
      attr_accessor :label
      attr_accessor :model_type
      attr_accessor :description
      attr_accessor :req_metadata_hash
      attr_accessor :hidden

      # init
      # @param hash [Hash]
      def initialize(hash)
        super()

        @name = "model_base"
        @hidden = true
        @model_type = :base
        @description = "Base model type"


        @req_metadata_hash = {}



        @_collection = :model
        from_hash(hash) unless hash == nil
      end




    end
  end
end
