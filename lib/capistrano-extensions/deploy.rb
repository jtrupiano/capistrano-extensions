require 'capistrano-extensions/geminstaller_dependency'

# Overrides the majority of recipes from Capistrano's deploy recipe set.
Capistrano::Configuration.instance(:must_exist).load do
  # Add us to the load path
  @load_paths << File.expand_path(File.dirname(__FILE__))

  # ========================================================================
  # These variables MUST be set in the client capfiles. If they are not set,
  # the deploy will fail with an error.
  # ========================================================================


  # =========================================================================
  # These variables may be set in the client capfile if their default values
  # are not sufficient.
  # =========================================================================

  _cset(:content_directories, []) # I'd like to eventually remove this...
  _cset(:shared_content, {})
  _cset(:rails_env) { ENV['RAILS_ENV'].nil? ? fetch(:deployable_environments).first : ENV['RAILS_ENV'] }  

  # =========================================================================
  # These variables should NOT be changed unless you are very confident in
  # what you are doing. Make sure you understand all the implications of your
  # changes if you do decide to muck with these!
  # =========================================================================

  set(:use_sudo, false)     # we don't want to use sudo-- we don't have to!
  set(:deploy_via, :export) # we don't want our .svn folders on the server!
  _cset(:deploy_to) { "/var/www/vhosts/#{application}" }
  _cset(:deployable_environments, [:production])

  _cset(:rails_config_path) { File.join(latest_release, 'config') }
  _cset(:db_conf)           { 
    fetch(:config_structure, :rails).to_sym == :sls ?
      File.join(rails_config_path, rails_env, 'database.yml') :
      File.join(rails_config_path, 'database.yml')
  }

  # Where uploaded content is stored
  _cset(:content_dir, "content")
  _cset(:content_path)  { File.join(shared_path, content_dir) }
  _cset(:public_path)   { File.join(latest_release, 'public') }
  _cset(:log_path)      { "/var/log/#{application}" }
  
  # Local Properties
  _cset(:tmp_dir, "tmp/cap")
  _cset(:store_dev_backups, false)
  _cset(:remote_backup_expires, 172800) # 2 days in seconds.
  _cset(:zip, "gzip")
  _cset(:unzip, "gunzip")
  _cset(:zip_ext, "gz")
  
  # Allow recipes to ask for a certain local environment
  def local_db_conf(env = nil)
    env ||= fetch(:rails_env)
    fetch(:config_structure, :rails).to_sym == :sls ?
      File.join('config', env.to_s, 'database.yml') :
      File.join('config', 'database.yml')
  end

  # Read from the local machine-- BE CAREFUL!!!
  set(:db) { YAML.load_file(local_db_conf)[rails_env] }

  # Let's define helpers for our deployable environments
  # Can we possibly just infer this from the config directory structure?
  deployable_environments.each do |env|
    src = <<-CODE
      def #{env.to_s}(&block)
        if rails_env.to_s == '#{env.to_s}'
          puts "*** Deploying to the \033[1;41m  #{env.to_s.capitalize} \033[0m server!"
          yield
          puts <<-DEBUG
            rails_env: \#{rails_env}
            deploy_to: \#{deploy_to}
            content_directories: \#{content_directories.join(', ')}
            shared_content: \#{shared_content.keys.join(', ')}
          DEBUG
        end
      end
    CODE
    eval src
  end

  # Now, let's actually include our common recipes!
  namespace :deploy do
    desc <<-DESC
      [capistrano-extensions] Creates shared directories and symbolic links to them by reading the 
      :content_directories and :shared_content properties.  See the README for further explanation.
    DESC
    task :create_shared_file_column_dirs, :roles => :app, :except => { :no_release => true } do
      mappings = content_directories.inject(shared_content) { |hsh, dir| hsh.merge({"content/#{dir}" => "public/#{dir}"}) }
      mappings.each_pair do |remote, local|
        run <<-CMD
          umask 0022 && 
          mkdir -p #{shared_path}/#{remote} &&
          ln -sf #{shared_path}/#{remote} #{latest_release}/#{local}
        CMD
      end
    end

    desc <<-DESC
      [capistrano-extensions]: Invokes geminstaller to ensure that the proper gem set is installed on 
      the target server.  Note that this task is not invoked by default, but rather is exposed to you
      as a helper.
    DESC
    task :gem_update, :roles => :app do
      run <<-CMD
        gem sources -u &&
        #{sudo} geminstaller -e -c #{rails_config_path}/geminstaller.yml
      CMD
    end

  end
  
  namespace :log do
    desc <<-DESC
      [capistrano-extensions]: Tarballs deployable environment's rails logfile (identified by 
      RAILS_ENV environment variable, which defaults to 'production') and copies it to the local
      filesystem
    DESC
    task :pull do
      tmp_location = "#{shared_path}/#{rails_env}.log.#{zip_ext}"
      run "cp #{log_path}/#{rails_env}.log #{shared_path}/ && #{zip} #{shared_path}/#{rails_env}.log"
      get "#{tmp_location}", "#{application}-#{rails_env}.log.#{zip_ext}"
      run "rm #{tmp_location}"
    end
  end

  load 'recipes/db_sync'
  load 'recipes/content_sync'
  
  namespace :remote do
    desc <<-DESC
      [capistrano-extensions]: Wrapper fro remote:sync_db and remote:sync_content.
      $> cap remote:sync FROM=production TO=staging
    DESC
    task :sync do
      sync_db
      sync_content
    end
  end

  namespace :local do
    desc <<-DESC
      [capistrano-extensions]: Wrapper for local:sync_db and local:sync_content
      $> cap local:sync RAILS_ENV=production RESTORE_ENV=development
    DESC
    task :sync do
      sync_db
      sync_content
    end
  end
  
  namespace :util do
    
    namespace :tmp do
      desc "[capistrano-extensions]: Displays warning if :tmp_dir has more than 10 files or is greater than 50MB"
      task :check do
        #[ 5 -le "`ls -1 tmp/cap | wc -l`" ] && echo "Display Me"
        cmd = %Q{ [ 10 -le "`ls -1 #{tmp_dir} | wc -l`" ] || [ 50 -le "`du -sh #{tmp_dir} | awk '{print int($1)}'`" ] && printf "\033[1;41m Clean up #{tmp_dir} directory \033[0m\n" && du -sh #{tmp_dir}/*  }
        system(cmd)
      end
      
      desc "[capistrano-extensions]: Remove the current remote env's backups from :tmp_dir"
      task :clean_remote do
        system("rm -f #{tmp_dir}/#{application}-#{rails_env}*")
      end
    
      # desc "Removes all but a single backup from :tmp_dir"
      # task :clean do
      #   
      # end
      # 
      # desc "Removes all tmp files from :tmp_dir"
      # task :remove do
      #   
      # end
    end
  end
  
end

def pluck_pass_str(db_config)
  pass_str = db_config['password']
  if !pass_str.nil?
    pass_str = "-p#{pass_str.gsub('$', '\$')}"
  end
  pass_str || ''
end

module LocalUtils
  def current_timestamp
    @current_timestamp ||= Time.now.to_i
  end

  def local_db_backup_file(args = {})
    env = args[:env] || rails_env
    timestamp = args[:timestamp] || current_timestamp
    "#{tmp_dir}/#{application}-#{env}-db-#{timestamp}.sql"
  end

  def local_content_backup_dir(args={})
    env = args[:env] || rails_env
    timestamp = args[:timestamp] || current_timestamp
    "#{tmp_dir}/#{application}-#{env}-content-#{timestamp}"
  end

  def retrieve_local_files(env, type)
    `ls -r #{tmp_dir} | awk -F"-" '{ if ($2 ~ /#{env}/ && $3 ~ /#{type}/) { print $4; } }'`.split(' ')
  end
end

module RemoteUtils
  def last_mod_time(path)
    capture("stat -c%Y #{path}").to_i
  end
  
  def server_cache_valid?(path)
    capture("[ -f #{path} ] || echo '1'").empty? && ((Time.now.to_i - last_mod_time(path)) <= remote_backup_expires) # two days in seconds
  end
end

include LocalUtils, RemoteUtils