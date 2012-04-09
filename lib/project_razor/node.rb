# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved


# Root ProjectRazor::Node namespace
# @author Nicholas Weaver
class ProjectRazor::Node < ProjectRazor::Object
  attr_accessor :name
  attr_accessor :attributes_hash
  attr_accessor :timestamp
  attr_accessor :last_state
  attr_accessor :current_state
  attr_accessor :next_state

  # init
  # @param hash [Hash]
  def initialize(hash)
    super()
    @_collection = :node
    @attributes_hash = {}
    from_hash(hash)
  end

  def tags
    # Dynamically return tags for this node
    engine = ProjectRazor::Engine.instance
    engine.node_tags(self)
  end

  # We override the to_hash to add the 'tags key/value for sharing node tags
  def to_hash
    hash = super
    hash['@tags'] = tags
    hash
  end

  def uuid=(new_uuid)
    @uuid = new_uuid.upcase
  end

  def print_header
    return "UUID", "Last Checkin", "Tags"
  end

  def print_items
    temp_tags = self.tags
    temp_tags = ["n/a"] if temp_tags == [] || temp_tags == nil
    return @uuid, Time.at(@timestamp).to_s, "[#{temp_tags.join(",")}]"
  end

  def line_color
    :white_on_black
  end

  def header_color
    :red_on_black
  end


  # Used to print our attributes_hash through slice printing
  # @return [Array]
  def print_attributes_hash

    # First see if we have the HashPrint class already defined
    begin
      self.class.const_get :HashPrint # This throws an error so we need to use begin/rescue to catch
    rescue
      # Define out HashPrint class for this object
      define_hash_print_class
    end

    # Create an array to store our HashPrint objects
    attr_array = []
    # Take each element in our attributes_hash and store as a HashPrint object in our array
    @attributes_hash.each do
    |k,v|
      # Skip any k/v where the v > 32 characters
      if v.to_s.length < 32
        # We use Name / Value as header and key/value as values for our object
        attr_array << ProjectRazor::Node::HashPrint.new(["Name", "Value"], [k.to_s, v.to_s], line_color, header_color)
      end
    end
    # Return our array of HashPrint
    attr_array
  end


end
