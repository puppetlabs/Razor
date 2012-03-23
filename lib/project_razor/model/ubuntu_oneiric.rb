# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved


# Root ProjectRazor namespace
# @author Nicholas Weaver
module ProjectRazor
  module Model
    # Root Model object
    # @author Nicholas Weaver
    # @abstract
    class UbuntuOneiricMinimal < ProjectRazor::Model::Base

      attr_accessor :hostname

      def initialize(hash)
        super(hash)
        @hidden = false
        @model_type = :linux_deploy
        @name = "ubuntu_oneiric_min"
        @description = "Ubuntu Oneiric 11.10 Minimal"
        @hostname = nil

        @req_metadata_hash = {
            "@hostname" => {:default => "",
                            :example => "hostname.example.org",
                            :validation => '^[\w.]+$',
                            :required => true,
                            :description => "node hostname"}
        }


        from_hash(hash) unless hash == nil
      end




    end
  end
end