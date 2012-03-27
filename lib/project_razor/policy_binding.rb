## EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
#   # Copyright © 2012 EMC Corporation, All Rights Reserved
#
#module ProjectRazor
#  # Used for binding of policy+models to a node
#  # this is permanent unless a user removed the binding or deletes a node
#  class PolicyBinding < ProjectRazor::Object
#
#    attr_accessor :timestamp
#    attr_accessor :node_uuid
#    attr_accessor :policy
#
#    def initialize(hash)
#      super()
#      @_collection = :bound_policy
#      from_hash(hash)
#    end
#  end
#end