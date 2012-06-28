
# Root ProjectRazor namespace
module ProjectRazor
  module Slice

    # ProjectRazor Slice Tag
    # Used for managing the tagging system
    class Tag < ProjectRazor::Slice::Base
      # Initializes ProjectRazor::Slice::Tag
      # @param [Array] args
      def initialize(args)
        super(args)
        @hidden = false
        @new_slice_style = true
        @slice_commands = {:add => "add_tagrule",
                           :get => {
                               :default => "get_all_tagrules",
                               :else => "get_tagrule_with_uuid",
                           },
                           :update => {
                               :default => "get_all_tagrules",
                               :else => "update_tagrule"
                           },
                           :remove => {
                               :all => "remove_all_tagrules",
                               :default => "get_all_tagrules",
                               :else => "remove_tagrule"
                           },
                           :matcher => {
                               :add => "add_matcher",
                               :get => {
                                   :default => "get_matcher_with_uuid",
                                   :else => "get_matcher_with_uuid"
                               },
                               :update => "update_matcher",
                               :remove => "remove_matcher",
                               :default => :get,
                               :else => :get
                           },
                           :default => "get_all_tagrules",
                           :else => :get,
                           :help => ""}
        @slice_name = "Tag"
      end


      #  Tag Rules
      #

      def get_all_tagrules
        # Get all tag rules and print/return
        @command = :get_all_tagrules
        @command_array.unshift(@last_arg) unless @last_arg == 'default'
        print_object_array(get_object("tagrules", :tag),
                           "Tag Rules",
                           :style => :table,
                           :success_type => :generic)
      end

      def get_tagrule_with_uuid
        @command = :get_tagrule_with_uuid
        @command_help_text = "razor tag [get] (uuid)"
        tagrule = get_object("tagrule_with_uuid",
                             :tag,
                             @command_array.first)
        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Tag Rule with UUID: [#{@command_array.first}]" unless tagrule
        print_object_array [tagrule], "", :success_type => :generic
      end

      def add_tagrule
        @command =:add_tagrule
        @command_help_text = "razor tag add {name=(name)} {tag=(tag)}"
        @name, @tag = *get_web_vars(%w(name tag)) if @web_command
        @name, @tag = *get_cli_vars(%w(name tag)) unless @name || @tag
        # Validate our args are here
        raise ProjectRazor::Error::Slice::MissingArgument, "Must Provide Tag Rule Name [name]" unless validate_arg(@name)
        raise ProjectRazor::Error::Slice::MissingArgument, "Must Provide Tag Rule Tag [tag]" unless validate_arg(@tag)
        tagrule = ProjectRazor::Tagging::TagRule.new({"@name" => @name, "@tag" => @tag})
        setup_data
        @data.persist_object(tagrule)
        if tagrule
          print_object_array([tagrule], "", :success_type => :created)
        else
          raise(ProjectRazor::Error::Slice::CouldNotCreate, "Could not create Tag Rule")
        end
      end

      def update_tagrule
        @command = :update_tagrule
        @command_help_text = "razor tag update (UUID) {name=(name)} {tag=(tag)}"
        tagrule_uuid = @command_array.shift
        tagrule = get_object("tagrule_with_uuid", :tag, tagrule_uuid)
        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Tag Rule with UUID: [#{tagrule_uuid}]" unless tagrule
        @name, @tag = *get_web_vars(%w(name tag)) if @web_command
        @name, @tag = *get_cli_vars(%w(name tag)) unless @name || @tag
        raise ProjectRazor::Error::Slice::MissingArgument, "Must provide at least one value to update" unless @name || @tag
        tagrule.name = @name if @name
        tagrule.tag = @tag if @tag
        raise ProjectRazor::Error::Slice::CouldNotUpdate, "Could not update Tag Rule [#{tagrule.uuid}]" unless tagrule.update_self
        print_object_array [tagrule], "", :success_type => :updated
      end

      def remove_all_tagrules
        @command = :remove_tagrule
        @command_help_text = "razor tag remove all"
        raise ProjectRazor::Error::Slice::CouldNotRemove, "Could not remove all Tag Rules" unless @data.delete_all_objects(:tag)
        slice_success("All Tag Rules removed", :success_type => :removed)
      end

      def remove_tagrule
        @command = :remove_tagrule
        @command_help_text = "razor tag remove (UUID)"
        tagrule_uuid = @command_array.shift
        tagrule = get_object("tagrule_with_uuid", :tag, tagrule_uuid)
        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Tag Rule with UUID: [#{tagrule_uuid}]" unless tagrule
        setup_data
        raise ProjectRazor::Error::Slice::CouldNotRemove, "Could not remove Tag Rule [#{tagrule.uuid}]" unless @data.delete_object(tagrule)
        slice_success("Tag Rule [#{tagrule.uuid}] removed", :success_type => :removed)
      end

      #
      #




      # Tag Matcher
      #

      def find_matcher(matcher_uuid)
        found_matcher = []
        setup_data
        @data.fetch_all_objects(:tag).each do
        |tr|
          tr.tag_matchers.each do
          |matcher|
            found_matcher << [matcher, tr] if matcher.uuid.scan(matcher_uuid).count > 0
          end
        end
        found_matcher.count == 1 ? found_matcher.first : nil
      end

      def get_matcher_with_uuid
        @command = :get_matcher_with_uuid
        @command_help_text = "razor tag matcher [get] (uuid)"
        matcher_uuid = @command_array.shift
        raise ProjectRazor::Error::Slice::MissingArgument, "Must provide a Tag Matcher UUID" unless validate_arg(matcher_uuid)
        matcher, tagrule = find_matcher(matcher_uuid)
        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot find Tag Matcher with UUID [#{matcher_uuid}]" unless matcher
        print_object_array [matcher], "", :success_type => :generic
      end

      def add_matcher
        @command =:add_matcher
        @command_help_text = "razor tag matcher add tag_rule_uuid=(tag rule key) key=(key) compare=[equal|like] value=(value) {invert=(yes)}\n"
        @command_help_text << "\t tag rule uuid: \t" + " Is the UUID of the parent Tag Rule to add the matcher to\n".yellow
        @command_help_text << "\t key: \t\t\t" + " the Node attribute key to match against\n".yellow
        @command_help_text << "\t compare: \t\t" + " Either [equal] for literal matching or [like] for regular expression\n".yellow
        @command_help_text << "\t value: \t\t" + " the value to match against the key\n".yellow
        @command_help_text << "\t inverse(OPTIONAL): \t"+" inverts so result is true if key does NOT match value\n".yellow
        @tag_rule_uuid, @key, @compare, @value, @invert = *get_web_vars(%w(tag_rule_uuid key compare value invert)) if @web_command
        @tag_rule_uuid, @key, @compare, @value, @invert = *get_cli_vars(%w(tag_rule_uuid key compare value invert)) unless @tag_rule_uuid || @key || @compare || @value || @invert
        # Validate our args are here
        raise ProjectRazor::Error::Slice::MissingArgument, "Must Provide Tag Rule UUID [tag_rule_uuid]" unless validate_arg(@tag_rule_uuid)
        @tagrule = get_object("tagrule_with_uuid", :tag, @tag_rule_uuid)
        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot Find Tag Rule with UUID: [#{@tag_rule_uuid}]" unless @tagrule
        @tag_rule_uuid = @tagrule.uuid
        raise ProjectRazor::Error::Slice::MissingArgument, "Must Provide Key [key]" unless validate_arg(@key)
        raise ProjectRazor::Error::Slice::MissingArgument, "Must Provide Compare[equal|like] [compare]" unless @compare == "equal" || @compare == "like"
        raise ProjectRazor::Error::Slice::MissingArgument, "Must Provide Value Tag [value]" unless validate_arg(@value)
        @invert = (@invert == "yes" || @invert == "true") ? "true" : "false"
        matcher = @tagrule.add_tag_matcher(:key => @key, :compare => @compare, :value => @value, :inverse => @invert)
        raise ProjectRazor::Error::Slice::CouldNotCreate, "Could not create tag matcher" unless matcher

        if @tagrule.update_self
          print_object_array([matcher], "Tag Matcher created:", :success_type => :created)
        else
          raise(ProjectRazor::Error::Slice::CouldNotCreate, "Could not create Tag Matcher")
        end
      end

      def update_matcher
        @command = :update_matcher
        @command_help_text = "razor tag matcher update (matcher uuid) key=(key) compare=[equal|like] value=(value) {invert=(yes)}\n"
        @command_help_text << "\t key: \t\t\t" + " the Node attribute key to match against\n".yellow
        @command_help_text << "\t compare: \t\t" + " Either [equal] for literal matching or [like] for regular expression\n".yellow
        @command_help_text << "\t value: \t\t" + " the value to match against the key\n".yellow
        @command_help_text << "\t inverse(OPTIONAL): \t"+" inverts so result is true if key does NOT match value\n".yellow
        matcher_uuid = @command_array.shift
        raise ProjectRazor::Error::Slice::MissingArgument, "Must provide a Tag Matcher UUID" unless validate_arg(matcher_uuid)
        matcher, tagrule = find_matcher(matcher_uuid)
        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot find Tag Matcher with UUID [#{matcher_uuid}]" unless matcher
        @key, @compare, @value, @invert = *get_web_vars(%w(key compare value invert)) if @web_command
        @key, @compare, @value, @invert = *get_cli_vars(%w(key compare value invert)) unless  @key || @compare || @value || @invert
        raise ProjectRazor::Error::Slice::MissingArgument, "Must provide at least one value to update" unless @key || @compare || @value || @invert
        raise ProjectRazor::Error::Slice::MissingArgument, "Must Provide Compare[equal|like] [compare]" if @compare && !(@compare == "equal" || @compare == "like")
        @invert = "true" if @invert == "yes"
        @invert = "false" if @invert == "no"
        matcher.key = @key if @key
        matcher.compare = @compare if @compare
        matcher.value = @value if @value
        matcher.inverse = @invert if @invert
        if tagrule.update_self
          print_object_array([matcher], "Tag Matcher updated [#{matcher.uuid}]\nTag Rule:", :success_type => :updated)
        else
          raise(ProjectRazor::Error::Slice::CouldNotCreate, "Could not update Tag Matcher")
        end
      end

      def remove_matcher
        @command = :get_matcher_with_uuid
        @command_help_text = "razor tag matcher remove (matcher uuid)\n"
        matcher_uuid = @command_array.shift
        raise ProjectRazor::Error::Slice::MissingArgument, "Must provide a Tag Matcher UUID" unless validate_arg(matcher_uuid)
        matcher, tagrule = find_matcher(matcher_uuid)
        raise ProjectRazor::Error::Slice::InvalidUUID, "Cannot find Tag Matcher with UUID [#{matcher_uuid}]" unless matcher
        raise ProjectRazor::Error::Slice::CouldNotCreate, "Could not remove Tag Matcher" unless tagrule.remove_tag_matcher(matcher.uuid)
        if tagrule.update_self
          print_object_array([tagrule], "Tag Matcher removed [#{matcher.uuid}]\nTag Rule:", :success_type => :removed)
        else
          raise(ProjectRazor::Error::Slice::CouldNotCreate, "Could not remove Tag Matcher")
        end
      end

      #
      #
    end
  end
end

