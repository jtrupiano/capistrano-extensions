require 'geminstaller'
require 'capistrano/recipes/deploy/remote_dependency'

def pluck_accessor_hash(obj, attrs = [])
  ret = {}
  attrs.each do |attr|
    ret[attr] = obj.send(attr)
  end
  ret
end

# open up existing RemoteDependency class, add support for gemfile
module Capistrano
  module Deploy
    class RemoteDependency

      def gemfile(path, options = {})
        registry = GemInstaller::Registry.new
        config_builder = registry.config_builder
        config_builder.config_file_paths = path
        config = config_builder.build_config
        gems = config.gems
        
        gems.each do |agem|
          # gem() function defined in Capistrano's RemoteDependency class
          options = pluck_accessor_hash(agem, [:platform, :install_options, :check_for_upgrade, :no_autogem, :fix_dependencies])
          gem(agem.name, agem.version, options)
        end
      end

    end
  end
end
