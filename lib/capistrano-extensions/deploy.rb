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

  # HOLDS REFERENCES TO EACH OF THE DEPLOYABLE ENVIRONMENT BLOCKS
  @env_procs = {}
      
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
          block.call if block_given?
          @env_procs[:#{env}] = block
        end
      end
    CODE
    eval src
  end


  # all deployable environments get a pseudo-namespaced role
  # as (e.g.) app_staging, app_production, web_staging, etc.
  #temp = {}
  #deployable_environments.each do |env|
  #  find_and_execute_task(env)
  #  roles.each { |name, role| temp[:"#{name}_#{env}"] = role }
  #  roles.clear    
  #end
  #temp.each { |name, role| roles[name] = role }

  # return the set of roles specific to an environment
  #def roles_for(env)
  #  roles.reject { |name, role| name =~ Regexp.new("/_#{env}$/") }
  #end


  # Helper function to allow you to temporarily change the deployment environment
  # Useful for when you need to deal with several deployable environments
  def change_deploy_env(new_env)
      # convert the current deploy environment to new_env
      old_rails_env = rails_env

      set(rails_env, new_env)
      roles.clear
      @env_procs[rails_env.to_sym].call

      server = Capistrano::ServerDefinition.new(ip, :user => user, :password => password) #@configuration.find_servers
      establish_connections_to([server])

      execute_on_servers do
        yield
      end      

  ensure
      # Set the environment back!
      set(rails_env, old_rails_env)
      roles.clear
      @env_procs[rails_env.to_sym].call

      server = Capistrano::ServerDefinition.new(ip) #@configuration.find_servers
      establish_connections_to([server])
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
        local_backup_file = "#{application}-#{env}-db.sql.gz}"
        upload(local_backup_file, "#{shared_path}/restore_db.sql.gz")
        #run "gunzip #{shared_path}/restore_db.sql.gz"
        #run "mysql -u #{user} --password=#{pass} #{db} < #{shared_path/restore_db.sql}"
        #run "rm -f #{shared_path}/restore_db.sql #{shared_path}/restore_db.sql.gz"
      end
    end

    desc <<-DESC
      [capistrano-extensions]: Backs up target deployable environment's database (identified
      by the FROM environment variable, which defaults to 'production') and restores it to 
      the remote database identified by the TO environment variable, which defaults to "staging"
    DESC
    task :copy_production_db do
      local::backup_db
      system("capistrano-extensions-copy-production-db #{ENV['FROM'] || 'production'||} #{ENV['TO'] || 'staging'}")
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
      [capistrano-extensions] Untars the backup file downloaded from local:backup_db (specified via the FROM env variable), 
      and imports (via mysql command line tool) it back into the database defined in the RAILS_ENV env variable.  
      Support now exists for RAILS_ENV to be a remote server.  You must first ensure that :deployable_environments has this environment.
      RAILS_ENV defaults to development.
    DESC
    task :restore_db, :roles => :db do
      env = ENV['FROM'] || 'production'
      
      env = ENV['RESTORE_ENV'] || 'development'
      y = YAML.load_file(local_db_conf(env))[env]
      db, user, pass = y['database'], y['username'], y['password'] # update me!

      puts "\033[1;41m Restoring database backup to #{rails_env} environment \033[0m"
      # local
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
    task :copy_production_db do
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
