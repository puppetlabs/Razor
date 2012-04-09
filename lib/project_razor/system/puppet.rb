# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved


require "system_base"

# Root namespace for ProjectRazor
# @author Nicholas Weaver
module ProjectRazor::System

  # Root namespace for Systems defined in ProjectRazor for node handoff
  # @author Nicholas Weaver
  class Puppet < ProjectRazor::System::Base

    def initialize(hash)
      super(hash)

    end

  end
end