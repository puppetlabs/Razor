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

      def version_weight
        # parse the version numbers from the @iso_version value (which could be
        # in the form of 0.9.5.0, v0.9.5.0, or even v0.9.5.0+15, where 15 is the
        # commit number since the Razor-Microkernel project was tagged)
        version_nums = /([0-9][\.\+]?)+/.match(@iso_version)[0].gsub("+", ".")
        # Limit any part of the version number to a number that is 999 or less
        version_nums.split(".").map! {|v| v.to_i > 999 ? 999 : v}.join(".")
        # and join them all into a single number for comparison (to determine which
        # image should be used)
        version_nums.split(".").map {|x| "%03d" % x}.join.to_i
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
