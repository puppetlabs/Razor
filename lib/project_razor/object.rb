# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved

require "uuid"
require "base62"
require "colored"
require "project_razor/utility"
require "project_razor/logging"

# Common object for all base ProjectRazor objects
# @abstract
class ProjectRazor::Object
  # Mixin our ObjectUtilities
  include(ProjectRazor::Utility)
  include(ProjectRazor::Logging)

  # There variables are required in all ProjectRazor objects
  attr_accessor :uuid # All objects must have a uuid / can be overridden in child object
  attr_accessor :version # All objects must have a version that is incremented on updates
  attr_accessor :classname # Classname will contain a string representation of the end Class / used for dynamically loading back from DB
  attr_accessor :_persist_ctrl # instance ref pointing to ProjectRazor::Persist::Controller of ProjectRazor::Data that created/fetched this object used for update/refresh
  attr_reader   :_collection # Collection/Table symbol for ProjectRazor::Persist::Controller / Must be specified(overridden) in each child class

  # Set default values
  def initialize
    @uuid = create_uuid
    @version = 0
    @classname = self.class.to_s
    @_collection = :object
    @_persist_ctrl = nil
  end

  # Refreshes object from Controller
  def refresh_self
    logger.debug "Refreshing object from persist controller"
    return false if @_persist_ctrl == nil
    new_hash = @_persist_ctrl.object_hash_get_by_uuid(self.to_hash, @_collection)
    self.from_hash(new_hash) unless new_hash == nil
    true
  end

  # Updates object through Controller
  def update_self
    logger.debug "Updating object in persist controller"
    return false if @_persist_ctrl == nil
    @_persist_ctrl.object_hash_update(self.to_hash, @_collection)
    refresh_self
    true
  end

  # Get logger object
  def get_logger
    logger
  end

  private

  # Return a new UUID string
  def create_uuid
    #logger.debug "Generate UUID" - commented out because it just junks up the log right now. TODO leave debug when Info is switched
    # using base62 gem now to make UUID string shorter by using 62 bit base.
    UUID.generate(format = :compact).to_i(16).base62_encode
  end

  # When called it creates a new dynamic object used for printing Hashes using slice printing
  def define_hash_print_class
    hash_print_class = Class.new do
      def initialize(print_header, print_items, line_color, header_color)
        @print_header = print_header
        @print_items = print_items
        @line_color = line_color
        @header_color = header_color

        @print_items.map! do
          |pi|
          case pi
            when nil, ""
              "n/a"
            else
              pi
          end
        end
      end
      attr_reader :print_header, :print_items, :line_color, :header_color
    end
    self.class.const_set :HashPrint, hash_print_class
  end
end