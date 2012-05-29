require "yaml"
require "digest/sha2"
require "extlib"

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

      def print_image_info(image_svc_path)
        super(image_svc_path)
        print "\tVersion: "
        print "#{@iso_version}  \n".green
        print "\tBuild Time: "
        print "#{Time.at(@iso_build_time)}  \n".green
      end

      def version_weight
        # Cap any subset with 999 being the maximum
        @iso_version.split(".").map! {|v| v.to_i > 999 ? 999 : v}.join(".")
        @iso_version.split(".").map {|x| "%03d" % x}.join.to_i
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
