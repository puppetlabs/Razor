# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved

# Used for all event-driven commands and policy resolution
# @author Nicholas Weaver

require "singleton"


module ProjectRazor
  class Engine
    include(ProjectRazor::Logging)
    include(Singleton)

    attr_accessor :policy_rules

    def initialize
      # create the singelton for policy_rules
      @policy_rules = ProjectRazor::PolicyRules.instance
    end

    def bound_policy
      $data.fetch_all_objects(:bound_policy)
    end





    #####################

    #####################
    ##### Default MK ####
    #####################

    def default_mk
      mk_images = []
      $data.fetch_all_objects(:images).each {|i| mk_images << i if i.path_prefix == "mk" && i.verify($data.config.image_svc_path) == true}



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


    # MK POLICY CHECKIN
    # Look for applicable policies
    # If found, bind, and reboot


    # BOOT POLICY CHECKIN
    # Look for applied policies
    # If found pass state receive boot script (install, boot)


    # STATE POLICY CHECKIN (Called by node install or ops & node_babysitter daemon)
    # Call-in for a state change for a node with a bound policy
    # Used to drive state changes within model and polling actions

    #####################
    ##### MK Section ####
    #####################

    def mk_checkin(input_uuid, last_state)
      old_timestamp = 0 # we set this early in case a timestamp field is nil

      uuid  = uuid_sanitize(input_uuid)
                        # We attempt to fetch the node object
      node = $data.fetch_object_by_uuid(:node, uuid)

      # Check to see if node is known
      if node

        # Node is known we need to update timestamp
        old_timestamp = node.timestamp unless node.timestamp == nil
        node.last_state = last_state    # We update last_state for the node
        node.timestamp = Time.now.to_i  # We update timestamp for the node
        unless node.update_self # Update node catching if it fails
          logger.error "Node #{node.uuid} checkin failed"
        end
        logger.debug "Node #{node.uuid} checkin accepted"

        # Check for a node action override
        forced_action = checkin_action_override(uuid)
        # Return the forced command if it exists
        logger.debug "Forced action for Node #{node.uuid} found (#{forced_action.to_s})" if forced_action
        return mk_command(forced_action,{}) if forced_action


        # Check to see if the time span since the last node contact
        # is greater than our register_timeout
        if (node.timestamp - old_timestamp) > $data.config.register_timeout
          # Our node hasn't talked to the server within an acceptable time frame
          # we will request a re-register to refresh details about the node
          logger.debug "Asking Node #{node.uuid} to re-register as we haven't talked to him in #{(node.timestamp - old_timestamp)} seconds"
          return mk_command(:register,{})
        end

        # Check to see if there is a bound policy
        # If there is we will call the mk_call method common to all policies
        # A bound policy means the node will never evaluate a policy rule
        # So for safety's sake - we set an extra flag (bound_policy_flag) which
        # prevents the policy eval below to run
        bound_policy = mk_check_bound_policy(node.uuid)




        if bound_policy
          command_array = bound_policy.policy.mk_call(node)
          return mk_command(command_array[0],command_array[1])
        else
          # Evaluate node vs policy rules to see if a policy needs to be bound
          mk_eval_vs_policy_rule(node)
        end


        # If we got to this point we just need to acknowledge the checkin
        mk_command(:acknowledge,{})

      else
        # Never seen this node - we tell it to checkin
        logger.debug "Unknown Node #{uuid}, asking to register"
        mk_command(:register,{})
      end
    end


    def mk_check_bound_policy(node_uuid)
      bound_policy.each do
      |bp|
        if bp.node_uuid == node_uuid
          return bp
        end
      end
      nil
    end


    def mk_eval_vs_policy_rule(node)
      logger.debug "Evaluating policy rules vs Node #{node.uuid}"

      # Loop through each rule checking node's tags to see if that match
      policy_rules.get.each do
      |pl|
        # Make sure there is at least one tag
        if pl.tags.count > 0
          if check_tags(node.tags, pl.tags)
            logger.debug "Matching policy rule (#{pl.name}) for Node #{node.uuid} using tags#{pl.tags.inspect}"
            # We found a policy that matches
            # we call the policy binding and exit loop
            mk_bind_policy(node, pl)
            return
          end
        else
          logger.error "Policy (#{pl.name}) has no tags configured"
        end
        logger.debug "No matching rules"
      end
    end


    def mk_bind_policy(node, policy_rule)
      logger.debug "Binding policy for Node (#{node.uuid}) to Policy (#{policy_rule.name})"
      policy_binding = ProjectRazor::PolicyBinding.new({})
      policy_binding.node_uuid = node.uuid
      policy_binding.policy = policy_rule
      policy_binding.timestamp = Time.now.to_i
      $data.persist_object(policy_binding)
    end


    # Used to override per-node checkin behavior for testing
    def checkin_action_override(uuid)
      checkin_file = "#{$razor_root}/conf/checkin_action.yaml"

      return nil unless File.exist?(checkin_file) # skip is file doesn't exist'
      f = File.open(checkin_file,"r")
      checkin_actions = YAML.load(f)
      checkin_actions[uuid] # return value for key matching uuid or nil if none
    end


    def mk_command(command_name, command_param)
      command_response = {}
      command_response['command_name'] = command_name
      command_response['command_param'] = command_param
      command_response
    end


    #######################
    ##### Boot Section ####
    #######################

    def boot_checkin(input_uuid)
      # Called by a node boot process

      # We sanitize the UUID to prevent compare issues
      uuid  = uuid_sanitize(input_uuid)

      logger.debug "Request for boot - uuid: #{uuid}"

      # We attempt to fetch the node object
      node = $data.fetch_object_by_uuid(:node, uuid)


      # If the node is in the DB we can check for bound policy on it
      if node != nil
        # Node is in DB, lets check for policy
        logger.debug "Node identified - uuid: #{node.uuid}"
        bound_policy = find_bound_policy(node)  # commented out until refactor

        If there is a bound policy we pass it the node to a common
        method call from a boot
        if bound_policy
          # Call the bound policy boot_call
          logger.debug "Active policy found (#{bound_policy.name}) for Node uuid: #{node.uuid}"
          bound_policy.boot_call(@node)
        else
        #There is not bound policy so we boot the MK
        logger.debug "No active policy found - uuid: #{node.uuid}"
        default_mk_boot(uuid)
        end
      else

        # Node isn't in DB, we boot it into the MK
        # This is a default behavior
        logger.debug "Node unknown - uuid: #{uuid}"
        default_mk_boot(uuid)
      end

    end


    def state_checkin

    end


    def find_bound_policy(node)
      bound_policies = $data.fetch_all_objects(:bound_policy)
      bound_policies.each do
      |bp|
        # If we find a bound policy we return it
        return bp.policy if uuid_sanitize(bp.uuid) == uuid_sanitize(node.uuid)
      end
      # Otherwise we return false indicating we have no policy
      false
    end




    def default_mk_boot(uuid)
      logger.debug "Responding with MK Boot - uuid: #{uuid}"
      default = ProjectRazor::Policy::BootMK.new
      default.get_boot_script
    end






    ######## Boot init section






    ########


    ########
    # Util #
    ########

    def check_tags(node_tags, policy_tags)
      policy_tags.each do
      |pt|
        return false unless node_tags.include?(pt)
      end
      true
    end

    def uuid_sanitize(uuid)
      uuid = uuid.gsub(/[:;,]/,"")
      uuid = uuid.upcase
    end


    def node_tags(node)
      node.attributes_hash
      tag_policies = $data.fetch_all_objects(:tag)

      tags = []
      tag_policies.each do
      |tag_pol|
        if tag_pol.check_tag_rule(node.attributes_hash)
          tags << tag_pol.tag
        end
      end
      tags
    end
  end
end
