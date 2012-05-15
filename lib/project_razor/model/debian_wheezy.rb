# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved

require "erb"

# TODO - timing between state changes
# TODO - timeout values for a state

# Root ProjectRazor namespace
# @author Nicholas Weaver
module ProjectRazor
  module ModelTemplate
    # Root Model object
    # @author Nicholas Weaver
    # @abstract
    class DebianWheezy < Debian
      include(ProjectRazor::Logging)

      # Assigned image
      attr_accessor :image_uuid
      # Metadata
      attr_accessor :hostname
      # Compatible Image Prefix
      attr_accessor :image_prefix

      def initialize(hash)
        super(hash)
        # Static config
        @hidden = false
        @name = "debian_wheezy"
        @description = "Debian Wheezy Model"
        # Metadata vars
        @hostname_prefix = nil
        # State / must have a starting state
        @current_state = :init
        # Image UUID
        @image_uuid = true
        # Image prefix we can attach
        @image_prefix = "os"
        # Enable agent brokers for this model
        @broker_plugin = :agent
        @osversion = 'wheezy'
        @final_state = :os_complete
        from_hash(hash) unless hash == nil
      end

    end
  end
end
