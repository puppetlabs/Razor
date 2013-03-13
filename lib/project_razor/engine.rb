# Used for all event-driven commands and policy resolution

require "singleton"
require "json"

module ProjectRazor
  class Engine < ProjectRazor::Object
    include(ProjectRazor::Logging)
    include(Singleton)

    attr_accessor :policies

    def initialize
      # create the singleton for policies
      @policies = ProjectRazor::Policies.instance
    end



    def get_active_models
      get_data.fetch_all_objects(:active)
    end

    #####################

    #####################
    ##### Default MK ####
    #####################

    def default_mk
      mk_images = []
      get_data.fetch_all_objects(:images).each { |i| mk_images << i if i.path_prefix == "mk" && i.verify(ProjectRazor.config.image_svc_path) == true }

      if mk_images.count > 0
        mk_image = nil
        mk_images.each do
        |i|
          mk_image = i if mk_image == nil
          mk_image = i if mk_image.version_weight < i.version_weight
        end

        mk_image
      else
        nil
      end
    end

    #####################
    ##### MK Section ####
    #####################

    def mk_checkin(uuid, last_state)
      old_timestamp = 0 # we set this early in case a timestamp field is nil
                        # We attempt to fetch the node object
      node          = get_data.fetch_object_by_uuid(:node, uuid)

      # Check to see if node is known
      if node

        # Node is known we need to update timestamp
        old_timestamp = node.timestamp unless node.timestamp == nil
        node.last_state = last_state    # We update last_state for the node
        node.timestamp  = Time.now.to_i # We update timestamp for the node
        unless node.update_self # Update node catching if it fails
          logger.error "Node #{node.uuid} checkin failed"
        end
        logger.debug "Node #{node.uuid} checkin accepted"

        # Check for a node action override
        forced_action = checkin_action_override(uuid)
        # Return the forced command if it exists
        logger.debug "Forced action for Node #{node.uuid} found (#{forced_action.to_s})" if forced_action
        return mk_command(forced_action, { }) if forced_action

        # Check to see if the time span since the last node contact
        # is greater than our register_timeout
        if (node.timestamp - old_timestamp) > ProjectRazor.config.register_timeout
          # Our node hasn't talked to the server within an acceptable time frame
          # we will request a re-register to refresh details about the node
          logger.debug "Asking Node #{node.uuid} to re-register as we haven't talked to him in #{(node.timestamp - old_timestamp)} seconds"
          return mk_command(:register, { })
        end

        # Check to see if there is an active model
        # If there is we will call the mk_call method common to all policies
        # A active model means the node will never evaluate a policy
        # So for safety's sake - we set an extra flag (active_models_flag) which
        # prevents the policy eval below to run
        active_model = find_active_models(node)

        if active_model
          command_array = active_model.mk_call(node)
          active_model.update_self
          return mk_command(command_array[0], command_array[1])
        else
          # Evaluate node vs policy rules to see if a policy needs to be bound
          mk_eval_vs_policy_rule(node)
        end

        # If we got to this point we just need to acknowledge the checkin
        mk_command(:acknowledge, { })

      else
        # Never seen this node - we tell it to checkin
        logger.debug "Unknown Node #{uuid}, asking to register"
        mk_command(:register, { })
      end
    end

    def mk_eval_vs_policy_rule(node)
      logger.debug "Evaluating policy rules vs Node #{node.uuid}"
      begin

        # Loop through each policy checking node's tags to see if that match
        @policies.get.each do
        |pl|
          # Make sure there is at least one tag
          if pl.tags.count > 0
            if check_tags(node.tags, pl.tags) && pl.enabled.to_s == "true" && pl.is_under_maximum?
              logger.debug "Matching policy (#{pl.label}) for Node #{node.uuid} using tags#{pl.tags.inspect}"
              # We found a policy that matches
              # we call the policy binding and exit loop
              mk_bind_policy(node, pl)
              return
            end
          else
            logger.error "Policy (#{pl.label}) has no tags configured"
          end
          logger.debug "No matching rules"
        end
      rescue => e
        logger.error e.message
      end
    end

    def mk_bind_policy(node, policy)
      if policy.bind_me(node)
        logger.debug "Binding policy for Node (#{node.uuid}) to Policy (#{policy.label})"
        get_data.persist_object(policy)
      else
        logger.error "Cannot bind Node (#{node.uuid}) to Policy (#{policy.label})"
      end
    end

    # Used to override per-node checkin behavior for testing
    def checkin_action_override(uuid)
      checkin_file = "#{$razor_root}/conf/checkin_action.yaml"

      return nil unless File.exist?(checkin_file) # skip is file doesn't exist'
      f               = File.open(checkin_file, "r")
      checkin_actions = YAML.load(f)
      checkin_actions[uuid] # return value for key matching uuid or nil if none
    end

    def mk_command(command_name, command_param)
      command_response                  = { }
      command_response['command_name']  = command_name
      command_response['command_param'] = command_param
      command_response
    end

    #######################
    ##### Boot Section ####
    #######################

    def boot_checkin(options = {})
      # Called by a node boot process

      logger.info "Request for boot - hw_id: #{options[:hw_id]}"

      # We attempt to fetch the node object
      node = lookup_node_by_hw_id(options)

      # If the node is in the DB we can check for active model on it
      if node != nil
        # Node is in DB, lets check for policy
        logger.info "Node identified - uuid: #{node.uuid}"
        active_model = find_active_models(node) # commented out until refactor
        # We update the dhcp_mac for the mac address that was booted
        if options[:dhcp_mac]
          node.dhcp_mac = options[:dhcp_mac]
          node.update_self
        end

        #If there is a active model we pass it the node to a common
        #method call from a boot
        if active_model
          # Call the active model boot_call
          logger.info "Active policy found (#{active_model.label}) for Node uuid: #{node.uuid}"
          boot_response = active_model.boot_call(node)
          get_data.persist_object(active_model)
          return boot_response
        else
          #There is not active model so we boot the MK
          logger.info "No active policy found - uuid: #{node.uuid}"
          default_mk_boot(node.uuid)
        end
      else

        # Node isn't in DB, we boot it into the MK
        # This is a default behavior
        logger.info "Node unknown - hw_id: #{options[:hw_id]}"
        default_mk_boot("unknown")
      end

    end

    def find_active_models(node)
      active_models = get_data.fetch_all_objects(:active)
      active_models.each do
      |bp|
        # If we find a active model we return it
        return bp if bp.node_uuid == node.uuid
      end
      # Otherwise we return false indicating we have no policy
      false
    end

    def default_mk_boot(uuid)
      logger.info "Responding with MK Boot - Node: #{uuid}"
      default = ProjectRazor::PolicyTemplate::BootMK.new({})
      default.get_boot_script(default_mk)
    end

    ########
    # Util #
    ########

    # This finds the correct node object with the provided node id's
    # If a new hw_id is sent and it not used somewhere else, it is added to the node's list
    #

    # @param [Hash] options
    # @return [Object,nil]
    def lookup_node_by_hw_id(options = { :hw_id => [] })
      unless options[:hw_id].count > 0
        return nil
      end
      matching_nodes = []
      nodes          = get_data.fetch_all_objects(:node)
      nodes.each do
      |node|
        matching_hw_id = node.hw_id & options[:hw_id]
        matching_nodes << node if matching_hw_id.count > 0
      end

      if matching_nodes.count > 1
        # uh oh - we have more than one
        # This should have been fixed during reg
        # this is fatal - we raise an error
        resolve_node_hw_id_collision
        matching_nodes = [lookup_node_by_hw_id(options)]
      end

      if matching_nodes.count == 1
        matching_nodes.first
      else
        nil
      end
    end

    # This creates a new node with the provided hw_ids and returns the new object
    #
    # @param [Hash] options
    # @return [Object,nil]
    def register_new_node_with_hw_id(node_object)
      # Ensure we have at least one hw_id
      unless node_object.hw_id.count > 0
        logger.error "Cannot register node without hw_id"
        return nil
      end
      # Verify none of the hw_id's are in use
      existing_node = lookup_node_by_hw_id(:hw_id => node_object.hw_id)
      if existing_node
        logger.error "Cannot register node with duplicate HW ID to existing node #{(existing_node.hw_id & node_object.hw_id).inspect} #{existing_node.uuid} #{node_object.uuid}"
        return nil
      end
      # Create new node object with node object
      new_node = get_data.persist_object(node_object)
      # run the resolve to be sure we don't have a conflict
      resolve_node_hw_id_collision
      new_node
    end

    # This is a failsafe should a duplicate hw_id happen. It removes the conflicted hw_id from a node object with the older timestamp
    #
    # @param [Array] hw_id
    def resolve_node_hw_id_collision
      # Get all nodes
      nodes     = get_data.fetch_all_objects(:node)
      # This will hold all hw_id's (not unique)'
      all_hw_id = []
      # Take each hw_id and add to our all_hw_id array
      nodes.each { |node| all_hw_id += node.hw_id }
      # Loop through each hw_id
      all_hw_id.each do
      |hwid|
        # This will hold nodes that match
        matching_nodes = []
        # loops through each node
        nodes.each do
        |node|
          # If the hwid is in the node.hw_id array then we add to the matching ndoes array
          matching_nodes << node if (node.hw_id & [hwid]).count > 0
        end
        # If we have more than one node we have a conflict
        # We sort by timestamp ascending
        matching_nodes.sort! { |a, b| a.timestamp <=> b.timestamp }
        # We remove the first one, any that remain will be cleaned of the hwid
        matching_nodes.shift
        # We remove the hw_id from each and persist
        matching_nodes.each do
        |node|
          node.hw_id.delete(hwid)
          node.update_self
        end
      end
      nil
    end

    def check_tags(node_tags, policy_tags)
      logger.debug "Node Tags: #{node_tags}"
      logger.debug "Policy Tags: #{policy_tags}"
      policy_tags.each do
      |pt|
        return false unless node_tags.include?(pt)
      end
      true
    end

    def uuid_sanitize(uuid)
      #uuid = uuid.gsub(/[:;,]/,"")
      #uuid.upcase
      uuid
    end

    def node_tags(node)
      node.attributes_hash
      tag_policies = get_data.fetch_all_objects(:tag)
      tag_policies = tag_policies + get_system_tags
      tags         = []
      tag_policies.each do
      |tag_pol|
        if tag_pol.check_tag_rule(node.attributes_hash)
          tags << tag_pol.get_tag(node.attributes_hash)
        end
      end
      # TODO remove any duplicates
      get_system_tags
      tags
    end

    def node_status(node)
      node.attributes_hash
      active_model = find_active_models(node)
      return "bound" if active_model
      max_active_elapsed_time = ProjectRazor.config.register_timeout
      time_since_last_checkin = Time.now.to_i - node.timestamp.to_i
      return "inactive" if time_since_last_checkin > max_active_elapsed_time
      return "active"
    end

    def get_system_tags
      system_tag_rules     = []
      system_tag_rules_dir = File.join(File.dirname(__FILE__), "tagging/system_rules/**/*.json")
      Dir.glob(system_tag_rules_dir).each do
      |json_file|
        begin
          system_tag_rules << JSON.parse(File.read(json_file))
        rescue => e
          logger.error "parsing error with json file: #{json_file}"
        end
      end
      system_tag_rules.map! do
      |tr|
        begin
          ProjectRazor::Tagging::TagRule.new(tr)
        rescue => e
          logger.error "converting to object error with hash: #{tr.inspect}"
        end
      end
      system_tag_rules
    end

    # removes all nodes that have not checked in during the last
    # node_expire_timeout seconds from the database
    def remove_expired_nodes(node_expire_timeout)
      node_array = get_data.fetch_all_objects(:node)
      node_array.each { |node|
        next if node_status(node) == "bound"
        elapsed_time = Time.now.to_i - node.timestamp.to_i
        if elapsed_time > node_expire_timeout
          node_uuid = node.uuid
          if get_data.delete_object(node)
            logger.info "expired node '#{node_uuid}' successfully removed from db"
          else
            logger.info "expired node '#{node_uuid}' could not be removed from db"
          end
        end
      }
    end

    # removes an image, but only if it's not part of a bound policy or a policy rule
    def remove_image(image)
      # ensure image is not actively part of a policy_rule or bound_policy within a model;
      # if so, then raise an exception (and return to the caller without removing the image)
      models = get_data.fetch_all_objects(:model)
      models.each { |model|
        if model.image_uuid == image.uuid
          logger.warn "Cannot remove image '#{image.uuid}' because it is used in model '#{model.uuid}'"
          raise Exception, "Cannot remove image '#{image.uuid}' because it is used in model '#{model.uuid}'"
        end
      }
      data = get_data
      unless image.remove(ProjectRazor.config.image_svc_path)
        logger.error 'attempt to remove image from image_svc_path failed'
        raise RuntimeError, "Attempt to remove image '#{image.uuid}' from the image_svc_path failed"
      end
      return data.delete_object(image)
    end


    # Returns a count of active models that match the policy uuid provided
    # @param [String] policy_uuid
    # @return [Integer]
    def policy_active_model_count(policy_uuid)
      get_active_models.count { |am| am.root_policy == policy_uuid }
    end


  end
end

