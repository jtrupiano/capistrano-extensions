# Overrides the majority of recipes from Capistrano's deploy recipe set.
Capistrano::Configuration.instance(:must_exist).load do
  # Add sls_recipes to the load path  
  @load_paths << File.expand_path(File.dirname(__FILE__))

  # ========================================================================
  # These variables MUST be set in the client capfiles. If they are not set,
  # the deploy will fail with an error.
  # ========================================================================


  # =========================================================================
  # These variables may be set in the client capfile if their default values
  # are not sufficient.
  # =========================================================================

  _cset(:content_directories, [])
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
  
  # Allow recipes to ask for a certain local environment
  def local_db_conf(env = nil)
    env ||= fetch(:rails_env)
    fetch(:config_structure, :rails).to_sym == :sls ?
      File.join('config', env, 'database.yml') :
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
          puts <<-DEBUG
            rails_env: \#{rails_env}
            deploy_to: \#{deploy_to}
            content_directories: \#{content_directories.join(', ')}
          DEBUG
          yield
        end
      end
    CODE
    eval src
  end

  # Now, let's actually include our common recipes!
  namespace :deploy do
    desc <<-DESC
      [capistrano-extensions] Creates shared filecolumn directories and symbolic links to them by 
      reading the :content_directories property.  Note that this task is not invoked by default,
      but rather is exposed to you as a helper.  To utilize, you'll want to override
      deploy:default and invoke this yourself.
    DESC
    task :create_shared_file_column_dirs, :roles => :app, :except => { :no_release => true } do
      content_directories.each do |fc|
        run <<-CMD
          mkdir -p #{content_path}/#{fc} && 
          ln -sf #{content_path}/#{fc} #{public_path}/#{fc} &&
          chmod 775 -R #{content_path}/#{fc}
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
        sudo geminstaller -e -c #{rails_config_path}/geminstaller.yml
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
      tmp_location = "#{shared_path}/#{rails_env}.log.gz"
      run "cp #{log_path}/#{rails_env}.log #{shared_path}/ && gzip #{shared_path}/#{rails_env}.log"
      get "#{tmp_location}", "#{application}-#{rails_env}.log.gz"
      run "rm #{tmp_location}"
    end
  end

  namespace :local do
    desc <<-DESC
      [capistrano-extensions]: Backs up deployable environment's database (identified by the 
      RAILS_ENV environment variable, which defaults to 'production') and copies it to the local machine
    DESC
    task :backup_db, :roles => :db do 
      run "mysqldump --user=#{db['username']} --password=#{db['password']} #{db['database']} > #{shared_path}/db_backup.sql"
      run "gzip #{shared_path}/db_backup.sql"
      get "#{shared_path}/db_backup.sql.gz", "#{application}-#{rails_env}-db.sql.gz"
      run "rm -f #{shared_path}/db_backup.sql.gz"
    end
    
    desc <<-DESC
      [capistrano-extensions] Untars the backup file downloaded from local:backup_db, and imports (via mysql command line 
      tool) it back into the local database defined in the RESTORE_ENV env variable
    DESC
    task :restore_db do
      env = ENV['RESTORE_ENV'] || 'development'
      y = YAML.load_file(local_db_conf(env))[env]
      db, user, pass = y['database'], y['username'], y['password'] # update me!
      
      system "gunzip #{application}-#{rails_env}-db.sql.gz"
      system "mysql -u #{user} --password=#{pass} #{db} < #{application}-#{rails_env}-db.sql"
      system "rm -f #{application}-#{rails_env}-db.sql"
    end
    
    desc <<-DESC
      [capistrano-extensions]: Downloads a tarball of uploaded content (that lives in public/ 
      directory, as specified by the :content_directories property) from the production site 
      back to the local filesystem
    DESC
    task :backup_content do
      run "cd #{content_path} && tar czf #{shared_path}/content_backup.tar.gz *"
      get "#{shared_path}/content_backup.tar.gz", "#{application}-#{rails_env}-content_backup.tar.gz"
      run "rm -f #{shared_path}/content_backup.tar.gz"
    end
    
    desc <<-DESC
      [capistrano-extensions]: Restores the backed up content to the local development environment app
    DESC
    task :restore_content do
      system "tar xzf #{application}-#{rails_env}-content_backup.tar.gz -C public/"
      system "rm -f #{application}-#{rails_env}-content_backup.tar.gz"
    end
    
    desc <<-DESC
      [capistrano-extensions]: Backs up target deployable environment's database (identified
      by the RAILS_ENV environment variable, which defaults to 'production') and restores it to 
      the local database identified by the RESTORE_ENV environment variable, which defaults to "development"
    DESC
    task :copy_production_db, :roles => :db do
      backup_db
      restore_db
    end
    
    desc <<-DESC
      [capistrano-extensions]: Backs up the target deployable environment's content directories (identified
      by the RAILS_ENV environment variable, which defaults to 'production') and restores them to the
      local development filesystem
    DESC
    task :copy_production_content do
      backup_content
      restore_content
    end
    
    desc <<-DESC
      [capistrano-extensions]: Copies all target (production or staging) data and content to a local environment
      identified by the RESTORE_ENV environment variable, which defaults to "development"
    DESC
    task :copy_production do
      copy_production_db
      copy_production_content
    end
  end
end
