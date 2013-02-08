require "yaml"
require "digest/sha2"

module ProjectRazor
  module ImageService
    # Image construct for Microkernel files
    class MicroKernel < ProjectRazor::ImageService::Base
      attr_accessor :mk_version
      attr_accessor :kernel
      attr_accessor :initrd
      attr_accessor :kernel_hash
      attr_accessor :initrd_hash
      attr_accessor :hash_description
      attr_accessor :iso_build_time
      attr_accessor :iso_version

      def initialize(hash)
        super(hash)
        @description = "MicroKernel Image"
        @path_prefix = "mk"
        @hidden = false
        from_hash(hash) unless hash == nil
      end

      def add(src_image_path, image_svc_path, extra)
        # Add the iso to the image svc storage
        begin
          resp = super(src_image_path, image_svc_path, extra)
          if resp[0]

            unless verify(image_svc_path)
              logger.error "Missing metadata"
              return [false, "Missing metadata"]
            end
            return resp
          else
            resp
          end
          rescue => e
            logger.error e.message
            raise ProjectRazor::Error::Slice::InternalError, e.message
        end
      end

      def verify(image_svc_path)
        unless super(image_svc_path)
          logger.error "File structure is invalid"
          return false
        end

        if File.exist?("#{image_path}/iso-metadata.yaml")
          File.open("#{image_path}/iso-metadata.yaml","r") do
          |f|
            @_meta = YAML.load(f)
          end

          set_hash_vars


          unless File.exists?(kernel_path)
            logger.error "missing kernel: #{kernel_path}"
            return false
          end

          unless File.exists?(initrd_path)
            logger.error "missing initrd: #{initrd_path}"
            return false
          end

          if @iso_build_time == nil
            logger.error "ISO build time is nil"
            return false
          end

          if @iso_version == nil
            logger.error "ISO build time is nil"
            return false
          end

          if @hash_description == nil
            logger.error "Hash description is nil"
            return false
          end

          if @kernel_hash == nil
            logger.error "Kernel hash is nil"
            return false
          end

          if @initrd_hash == nil
            logger.error "Initrd hash is nil"
            return false
          end

          digest = ::Object::full_const_get(@hash_description["type"]).new(@hash_description["bitlen"])
          khash = File.exist?(kernel_path) ? digest.hexdigest(File.read(kernel_path)) : ""
          ihash = File.exist?(initrd_path) ? digest.hexdigest(File.read(initrd_path)) : ""

          unless @kernel_hash == khash
            logger.error "Kernel #{@kernel} is invalid"
            return false
          end

          unless @initrd_hash == ihash
            logger.error "Initrd #{@initrd} is invalid"
            return false
          end

          true
        else
          logger.error "Missing metadata"
          false
        end
      end

      def set_hash_vars
        if @iso_build_time ==nil ||
            @iso_version == nil ||
            @kernel == nil ||
            @initrd == nil

          @iso_build_time = @_meta['iso_build_time'].to_i
          @iso_version = @_meta['iso_version']
          @kernel = @_meta['kernel']
          @initrd = @_meta['initrd']
        end

        if @kernel_hash == nil ||
            @initrd_hash == nil ||
            @hash_description == nil

          @kernel_hash = @_meta['kernel_hash']
          @initrd_hash = @_meta['initrd_hash']
          @hash_description = @_meta['hash_description']
        end
      end

      # Used to calculate a "weight" for a given ISO version.  These weights
      # are used to determine which ISO to use when multiple Razor-Microkernel
      # ISOS are available.  The complexity in this function results from it's
      # support for the various version numbering schemes that have been used
      # in the Razor-Microkernel project over time.  The following four version
      # numbering schemes are all supported:
      #
      #    v0.9.3.0
      #    v0.9.3.0+48-g104a9bc
      #    0.10.0
      #    0.10.0+4-g104a9bc
      #
      # Note that the syntax that is supported is an optional 'v' character
      # followed by a 3 or 4 part version number.  Either of these two formats
      # can be used for the "version tag" that is applied to any given
      # Razor-Microkernel release.  The remainder (if it exists) shows the commit
      # number and commit string for the latest commit (if that commit differs
      # from the tagged version).  These strings are converted to a floating point
      # number for comparison purposes, with later releases (in the semantic
      # versioning sense of the word "later") converting to larger floating point
      # numbers
      def version_weight
        # parse the version numbers from the @iso_version value
        version_str, commit_no = /^v?(.*)$/.match(@iso_version)[1].split("-")[0].split("+")
        # Limit any part of the version number to a number that is 999 or less
        version_str.split(".").map! {|v| v.to_i > 999 ? 999 : v}.join(".")
        # separate out the semantic version part (which looks like 0.10.0) from the
        # "sub_patch number" (to handle formats like v0.9.3.0, which were used in
        # older versions of the Razor-Microkernel project)
        version_parts = version_str.split(".").map {|x| "%03d" % x}
        sub_patch = (version_parts.length == 4 ? version_parts[3] : "000")
        # and join the parts as a single floating point number for comparison
        (version_parts[0,3].join + ".#{sub_patch}").to_f + "0.000#{commit_no}".to_f
      end

      def print_item_header
        super.push "Version", "Built Time"
      end

      def print_item
        super.push @iso_version.to_s, (Time.at(@iso_build_time)).to_s
      end

      def kernel_path
        image_path + "/" + @kernel
      end

      def initrd_path
        image_path + "/" + @initrd
      end

    end
  end
end
