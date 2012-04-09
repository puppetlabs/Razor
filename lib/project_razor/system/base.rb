# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved


# Root namespace for ProjectRazor
# @author Nicholas Weaver
module ProjectRazor::System

  # Root namespace for Systems defined in ProjectRazor for node handoff
  # @author Nicholas Weaver
  # @abstract
  class Base

    attr_accessor :system_type
    attr_accessor :system_server

    def initialize(hash)


      @hidden = :true
      @system_type = :base
      @_collection = :system
      from_hash(hash) if hash
    end



  end
end