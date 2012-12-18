require "rspec"
require "project_razor"

def default_config
  ProjectRazor::Config::Server.new
end

def bootmk_get_boot_script_from_config(hash)
  config = default_config
  hash.each do |key,val|
    config.instance_variable_set('@'+key, val)
  end
  write_config(config)

  testee = ProjectRazor::PolicyTemplate::BootMK.new({})
  mk = ProjectRazor::ImageService::MicroKernel.new({})
  output = testee.get_boot_script(mk)
  output
end

def write_config(config)
  # First delete any existing default config
  File.delete($config_server_path) if File.exists?($config_server_path)
  # Now write out the default config above
  f = File.open($config_server_path, 'w+')
  f.write(YAML.dump(config))
  f.close
end


describe ProjectRazor::PolicyTemplate::BootMK do
  describe ".get_boot_script" do

    before(:all) do
      #Backup existing razor_server.conf being nice to the developer's environment
      FileUtils.mv($config_server_path, "#{$config_server_path}.backup", :force => true) if File.exists?($config_server_path)
    end
  
    after(:all) do
      #Restore razor_server.conf back
      if File.exists?("#{$config_server_path}.backup")
        File.delete($config_server_path)
        FileUtils.mv("#{$config_server_path}.backup", $config_server_path, :force => true) if File.exists?("#{$config_server_path}.backup")
      else
        write_config(default_config)
      end
    end

    it "should append the contents of rz_mk_boot_kernel_args to the iPXE kernel-line, if configured" do
      output = bootmk_get_boot_script_from_config({'rz_mk_boot_kernel_args' => 'razor.ip=1.2.3.4'})
      output.should include('razor.ip=1.2.3.4') 
    end
  
    it "should append the contents of rz_mk_boot_debug_level if it is configured and matches 'quiet'" do
      output = bootmk_get_boot_script_from_config({'rz_mk_boot_debug_level' => 'quiet'})
      output.should include('quiet')
    end
  
    it "should append the contents of rz_mk_boot_debug_level if it is configured and matches 'debug'" do
      output = bootmk_get_boot_script_from_config({'rz_mk_boot_debug_level' => 'debug'})
      output.should include('debug')
    end
  
    it "should not append the contents of rz_mk_boot_debug_level if it does not match 'quiet' or 'debug'" do
      output = bootmk_get_boot_script_from_config({'rz_mk_boot_debug_level' => 'fubar'})
      output.should_not include('fubar')
    end
      
    it "should append the contents of rz_mk_boot_debug_level + rz_boot_kernel_args if both are configured" do
      output = bootmk_get_boot_script_from_config({'rz_mk_boot_debug_level' => 'debug', 'rz_mk_boot_kernel_args' => 'razor.ip=1.2.3.4'})
      output.should include('debug razor.ip=1.2.3.4')
    end
  end
end

