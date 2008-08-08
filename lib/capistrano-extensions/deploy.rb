require 'capistrano-extensions/geminstaller_dependency'
require 'capistrano/server_definition'

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
          yield
          puts <<-DEBUG
            rails_env: \#{rails_env}
            deploy_to: \#{deploy_to}
            content_directories: \#{content_directories.join(', ')}
          DEBUG
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
      tmp_location = "#{shared_path}/#{rails_env}.log.gz"
      run "cp #{log_path}/#{rails_env}.log #{shared_path}/ && gzip #{shared_path}/#{rails_env}.log"
      get "#{tmp_location}", "#{application}-#{rails_env}.log.gz"
      run "rm #{tmp_location}"
    end
  end

  namespace :remote do
    desc <<-DESC
      [capistrano-extensions] Uploads the backup file downloaded from local:backup_db (specified via the FROM env variable), 
      copies it to the remove environment specified by RAILS_ENV, and imports (via mysql command line tool) it back into the 
      remote database.
    DESC
    task :restore_db, :roles => :db do
      env = ENV['FROM'] || 'production'
      
      puts "\033[1;41m Restoring database backup to #{rails_env} environment \033[0m"
      if deployable_environments.include?(rails_env.to_sym)
        # remote environment
        local_backup_file = "#{application}-#{env}-db.sql.gz"
        remote_file       = "#{shared_path}/restore_db.sql"
        if !File.exists?(local_backup_file)
          puts "Could not find backup file: #{local_backup_file}"
          exit 1
        end
        upload(local_backup_file, "#{remote_file}.gz")
        run "gunzip -f #{remote_file}.gz"
        run "mysql -u #{db['username']} --password=#{db['password']} #{db['database']} < #{remote_file}"
        run "rm -f #{remote_file}"
      end
    end

    desc <<-DESC
      [capistrano-extensions]: Backs up target deployable environment's database (identified
      by the FROM environment variable, which defaults to 'production') and restores it to 
      the remote database identified by the TO environment variable, which defaults to "staging."
    DESC
    task :sync_db do
      system("capistrano-extensions-sync-db #{ENV['FROM'] || 'production'} #{ENV['TO'] || 'staging'}")
    end

    desc <<-DESC
      [capistrano-extensions]: Uploads the backup file downloaded from local:backup_content (specified via the FROM env variable), 
        copies it to the remote environment specified by RAILS_ENV, and unpacks it into the shared/ 
        directory.
    DESC
    task :restore_content do
      from = ENV['FROM'] || 'production'
      
      if deployable_environments.include?(rails_env.to_sym)
        local_backup_file = "#{application}-#{from}-content_backup.tar.gz"
        remote_file       = "#{content_path}/content_backup.tar.gz"
        
        if !File.exists?(local_backup_file)
          puts "Could not find backup file: #{local_backup_file}"
          exit 1
        end
        
        upload(local_backup_file, "#{remote_file}")
        run("tar xzf #{remote_file} -C #{content_path}/")
        run("rm -f #{remote_file}")
      end
    end
    
    desc <<-DESC
      [capistrano-extensions]: Backs up target deployable environment's shared content (identified by the FROM environment 
        variable, which defaults to 'production') and restores it to the remote environment identified 
        by the TO envrionment variable, which defaults to "staging."  

        Because multiple capistrano configurations must be loaded, an external executable
        (capistrano-extensions-sync_content) is invoked, which independently calls capistrano.  See the 
        executable at $GEM_HOME/capistrano-extensions-0.1.2/bin/capistrano-extensions-sync_content

        $> cap remote:sync_content FROM=production TO=staging
    DESC
    task :sync_content do
      system("capistrano-extensions-sync-content #{ENV['FROM'] || 'production'} #{ENV['TO'] || 'staging'}")
    end
    
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
      [capistrano-extensions]: Backs up deployable environment's database (identified by the 
      RAILS_ENV environment variable, which defaults to 'production') and copies it to the local machine
    DESC
    task :backup_db, :roles => :db do 
      run "mysqldump --user=#{db['username']} --password=#{db['password']} #{db['database']} > #{shared_path}/db_backup.sql"
      run "gzip #{shared_path}/db_backup.sql"
      get "#{shared_path}/db_backup.sql.gz", "#{application}-#{rails_env}-db.sql.gz"
      run "rm -f #{shared_path}/db_backup.sql.gz #{shared_path}/db_backup.sql"
    end
    
    desc <<-DESC
      [capistrano-extensions] Untars the backup file downloaded from local:backup_db (specified via the FROM env 
      variable, which defalts to RAILS_ENV), and imports (via mysql command line tool) it back into the database 
      defined in the RAILS_ENV env variable.
      
      ToDo: implement proper rollback: currently, if the mysql import succeeds, but the rm fails,
      the database won't be rolled back.  Not sure this is even all that important or necessary, since
      it's a local database that doesn't demand integrity (in other words, you're still going to have to
      fix it, but it's not mission critical).
    DESC
    task :restore_db, :roles => :db do
      on_rollback { "gzip #{application}-#{from}-db.sql"}
      
      from = ENV['FROM'] || rails_env
      
      env = ENV['RESTORE_ENV'] || 'development'
      y = YAML.load_file(local_db_conf(env))[env]
      db, user, pass = y['database'], y['username'], y['password'] # update me!

      puts "\033[1;41m Restoring database backup to #{env} environment \033[0m"
      # local
      system <<-CMD
        gunzip #{application}-#{from}-db.sql.gz &&
        mysql -u #{user} -p#{pass} #{db} < #{application}-#{from}-db.sql
      CMD
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
      [capistrano-extensions]: Restores the backed up content (evn var FROM specifies which environment
      was backed up, defaults to RAILS_ENV) to the local development environment app
    DESC
    task :restore_content do
      from = ENV['FROM'] || rails_env
      
      system "tar xzf #{application}-#{from}-content_backup.tar.gz -C public/"
      system "rm -f #{application}-#{from}-content_backup.tar.gz"
    end
    
    desc <<-DESC
      [capistrano-extensions]: Wrapper for local:backup_db and local:restore_db.      
      $> cap local:sync_db RAILS_ENV=production RESTORE_ENV=development
    DESC
    task :sync_db do
      transaction do
        backup_db
        ENV['FROM'] = rails_env
        restore_db
      end
    end
    
    desc <<-DESC
      [capistrano-extensions]: Wrapper for local:backup_content and local:restore_content
      $> cap local:sync_content RAILS_ENV=production RESTORE_ENV=development
    DESC
    task :sync_content do
      transaction do
        backup_content
        restore_content
      end
    end
    
    desc <<-DESC
      [capistrano-extensions]: Wrapper for local:sync_db and local:sync_content
      $> cap local:sync RAILS_ENV=production RESTORE_ENV=development
    DESC
    task :sync do
      sync_db
      sync_content
    end
  end
end
