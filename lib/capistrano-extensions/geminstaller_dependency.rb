require 'geminstaller'

Capistrano::Configuration.instance(:must_exist).load do

  def pluck_accessor_hash(obj, attrs = [])
    ret = {}
    attrs.each do |attr|
      ret[attr] = obj.send(attr)
    end
    ret
  end

  alias :depend_without_gemfile :depend

  # Auxiliary helper method for the `deploy:check' task. Lets you set up your
  # own dependencies.
  def depend(location, type, *args)
    if type == :gemfile
      registry = GemInstaller::Registry.new
      config_builder = registry.config_builder
      path = args.pop
      config_builder.config_file_paths = path
      config = config_builder.build_config
      gems = config.gems
      
      gems.each do |agem|
        # gem() function defined in Capistrano's RemoteDependency class
        options = pluck_accessor_hash(agem, [:platform, :install_options, :check_for_upgrade, :no_autogem, :fix_dependencies])
        depend_without_gemfile(location, :gem, agem.name, agem.version, options)
      end
    else
      depend_without_gemfile(location, type, *args)
    end
  end
end
