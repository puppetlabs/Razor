# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved

require "json"
require "yaml"

# Root ProjectRazor namespace
# @author Nicholas Weaver
module ProjectRazor
  module Slice

    # TODO - add inspection to prevent duplicate MK's with identical version to be added

    # ProjectRazor Slice ImageSvc
    # Used for image management
    # @author Nicholas Weaver
    class Imagesvc < ProjectRazor::Slice::Base
      # Initializes ProjectRazor::Slice::Model including #slice_commands, #slice_commands_help, & #slice_name
      # @param [Array] args
      def initialize(args)
        super(args)
        # Here we create a hash of the command string to the method it corresponds to for routing.
        @slice_commands = {:add => "add_image",
                           :get => "list_images",
                           :remove => "remove_image",
                           :default => "list_images",
                           :path => "get_path"}
        @slice_commands_help = {:add => "imagesvc add " + "[mk|os]".blue + " (PATH TO ISO)".yellow,
                                :get => "imagesvc " + "[get]".blue,
                                :remove => "imagesvc remove " + "(IMAGE UUID)".yellow,
                                :default => "imagesvc " + "[get]".blue}
        @slice_name = "Imagesvc"
      end

      #Gets the path to an image or image element
      # /mk/kernel - gets default mk kernel
      # /mk/initrd - gets default mk initrd
      # /%uuid&/%path to file% - gets the file from relative path for image with %uuid%


      def get_path
        if @web_command
          @arg = @command_array.shift
          if @arg != nil
            case @arg

              when "mk"
                get_mk_paths
              else
                get_path_with_uuid(@arg)
            end
          else
            slice_error("MissingArgument", false)
          end
        else
          slice_error("NotImplemented", false)
        end
      end

      def get_mk_paths
        engine = ProjectRazor::Engine.instance
        default_mk_image = engine.default_mk

        if default_mk_image != nil
          @option = @command_array.shift
          if @option != nil

            setup_data
            case @option
              when "kernel"
                slice_success(default_mk_image.kernel_path,false)

              when "initrd"
                slice_success(default_mk_image.initrd_path,false)

              else
                slice_error("MissingOption", false)
            end
          else
            slice_error("MissingOption", false)
          end
        else
          slice_error("NoMKLoaded", false)
        end
      end

      def get_path_with_uuid(uuid)


      end

      #Lists images
      def list_images
        if @web_command
          slice_error("CLIOnlySlice", false)
        else
          print_images get_object("images", :images)
        end
      end

      #Add an image
      def add_image
        @command = :add
        setup_data
        image_types = {:mk => {:desc => "MicroKernel ISO",
                               :classname => "ProjectRazor::ImageService::MicroKernel",
                               :method => "add_mk"},
                       :os => {:desc => "OS Install ISO",
                               :classname => "ProjectRazor::ImageService::OSInstall",
                               :method => "add_os"}}
        if @web_command
          slice_error("CLIOnlySlice", false)
        else

          image_type = @command_array.shift

          unless check_against_types(image_type, image_types)
            print_types(image_types)
            slice_error("InvalidImageType", false)
            return
          end

          iso_path = @command_array.shift
          unless iso_path != nil && iso_path != ""
            slice_error("NoISOProvided", false)
            return
          end

          classname = image_types[image_type.to_sym][:classname]


          new_image = Object::full_const_get(classname).new({})
          # We send the new image object to the appropriate method
          res = self.send image_types[image_type.to_sym][:method], new_image, iso_path, @data.config.image_svc_path

          unless res[0]
            slice_error(res[1], false)
            return
          end


          unless insert_image(new_image)
            slice_error("CouldNotSaveImage", false)
            return
          end

          puts "\nNew image added successfully\n".green
          print_images [new_image]
        end
      end

      def add_mk(new_image, iso_path, image_svc_path)
        puts "Attempting to add, please wait...".green
        new_image.add(iso_path, image_svc_path, nil)
      end

      def add_os(new_image, iso_path, image_svc_path)
        os_name = @command_array.shift
        if os_name == nil
          @slice_commands_help[:add] = "imagesvc add os #{iso_path} ".white + "(OS Name) (OS Version)".red
          return [false, "MissingOSName"]
        end

        os_version = @command_array.shift
        if os_version == nil
          @slice_commands_help[:add] = "imagesvc add os #{iso_path} #{os_name} ".white + "(OS Version)".red
          return [false, "MissingOSVersion"]
        end

        puts "Attempting to add, please wait...".green
        new_image.add(iso_path, image_svc_path, {:os_version => os_version, :os_name => os_name})
      end

      def insert_image(image_obj)
        setup_data
        image_obj = @data.persist_object(image_obj)
        image_obj.refresh_self
      end

      def print_types(types)
        puts "\nPlease select a valid image type.\nValid types are:".red
        types.each_key do
        |k|
          print "\t[#{k}]".yellow
          print " - "
          print "#{types[k][:desc]}".yellow
          print "\n"
        end
      end

      def check_against_types(type,types)
        types.each_key do
        |k|
          return true if type == k.to_s
        end
        false
      end


      def remove_image
        @command = :remove

        if @web_command
          slice_error("CLIOnlySlice", false)
        else
          image_uuid = @command_array.shift
          if image_uuid == nil
            slice_error("NoUUIDProvided", false)
            return
          else
            setup_data
            image_selected = @data.fetch_object_by_uuid(:images, image_uuid)
            if image_selected == nil
              slice_error("NoImageFoundWithUUID", false)
              return
            else

              # TODO - Add cross check against engine to be sure image is not actively part of a policy_rule or bound_policy within a model

              if image_selected.remove(@data.config.image_svc_path)
                if @data.delete_object(image_selected)
                  slice_success("",false)
                  puts "\nImage: " + "#{image_uuid}".yellow + " removed successfully"
                  return
                else
                  slice_error("CannotRemoveImageFromDB", false)
                  return
                end
              else
                slice_error("CannotRemoveImagePath", false)
                return
              end
            end
          end
        end
      end


      # Handles printing of image details to CLI
      # @param [Array] images_array
      def print_images(images_array)
        unless @web_command
          puts "Images:"

          unless @verbose
            images_array.each do
            |image|
              image.print_image_info(@data.config.image_svc_path)
              print "\n"
            end
          else
            images_array.each do
            |image|
              image.instance_variables.each do
              |iv|
                unless iv.to_s.start_with?("@_")
                  key = iv.to_s.sub("@", "")
                  print "#{key}: "
                  print "#{image.instance_variable_get(iv)}  ".green
                end
              end
              print "\n"
            end
          end
        else
          images_array = images_array.collect { |image| image.to_hash }
          slice_success(images_array, false)
        end
      end

    end
  end
end
