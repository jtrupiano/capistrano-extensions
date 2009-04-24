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
  _cset(:zip, "gzip")
  _cset(:unzip, "gunzip")
  _cset(:zip_ext, "gz")
  _cset(:store_dev_backups, false)
  
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
        local_backup_file = "#{application}-#{env}-db.sql.#{zip_ext}"
        remote_file       = "#{shared_path}/restore_db.sql"
        if !File.exists?(local_backup_file)
          puts "Could not find backup file: #{local_backup_file}"
          exit 1
        end
        upload(local_backup_file, "#{remote_file}.#{zip_ext}")

        pass_str = pluck_pass_str(db)
        run "#{unzip} -f #{remote_file}.#{zip_ext}"
        run "mysql -u#{db['username']} #{pass_str} #{db['database']} < #{remote_file}"
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
      [capistrano-extensions]: Uploads the backup file downloaded from local:backup_content (specified via the 
      FROM env variable), copies it to the remote environment specified by RAILS_ENV, and unpacks it into the 
      shared/ directory.
    DESC
    task :restore_content do
      from = ENV['FROM'] || 'production'
      
      if deployable_environments.include?(rails_env.to_sym)
        local_backup_file = "#{application}-#{from}-content_backup.tar.#{zip_ext}"
        remote_file       = "#{shared_path}/content_backup.tar.#{zip_ext}"
        
        if !File.exists?(local_backup_file)
          puts "Could not find backup file: #{local_backup_file}"
          exit 1
        end
        
        upload(local_backup_file, "#{remote_file}")
        remote_dirs = ["content"] + shared_content.keys
        
        run("cd #{shared_path} && rm -rf #{remote_dirs.join(' ')} && tar xzf #{remote_file} -C #{shared_path}/")
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
      pass_str = pluck_pass_str(db)
      
      # sort by last alphabetically (forcing the most recent timestamp to the top)
      files = `ls -r #{tmp_dir} | awk -F"-" '{ if ($2 ~ /#{rails_env}/ && $3 ~ /db/) { print $4; } }'`.split(' ')

      if files.empty?
        # pull it from the server
        run "mysqldump --add-drop-database -u#{db['username']} #{pass_str} #{db['database']} > #{shared_path}/db_backup.sql"
        run "rm -f #{shared_path}/db_backup.sql.#{zip_ext} && #{zip} #{shared_path}/db_backup.sql"
        system "mkdir -p #{tmp_dir}"
        get "#{shared_path}/db_backup.sql.#{zip_ext}", "#{local_db_backup_file}.#{zip_ext}"
        run "rm -f #{shared_path}/db_backup.sql.#{zip_ext} #{shared_path}/db_backup.sql"
      else
        # set us up to use the cache
        @current_timestamp = files.first.to_i # actually has the extension hanging off of it, but shouldn't be a problem
      end
    end
        
    desc <<-DESC
      [capistrano-extensions] Untars the backup file downloaded from local:backup_db (specified via the FROM env 
      variable, which defalts to RAILS_ENV), and imports (via mysql command line tool) it back into the database 
      defined in the RESTORE_ENV env variable (defaults to development).
      
      ToDo: implement proper rollback: currently, if the mysql import succeeds, but the rm fails,
      the database won't be rolled back.  Not sure this is even all that important or necessary, since
      it's a local database that doesn't demand integrity (in other words, you're still going to have to
      fix it, but it's not mission critical).
    DESC
    task :restore_db, :roles => :db do
      from = ENV['FROM'] || rails_env
      env  = ENV['RESTORE_ENV'] || 'development'
      
      y = YAML.load_file(local_db_conf(env))[env]
      db, user = y['database'], (y['username'] || 'root') # update me!

      pass_str = pluck_pass_str(y)
      mysql_str  = "mysql -u#{user} #{pass_str} #{db}"
      mysql_dump = "mysqldump --add-drop-database -u#{user} #{pass_str} #{db}"
      
      local_backup_file  = local_db_backup_file(:env => env)
      remote_backup_file = local_db_backup_file(:env => from)

      # we're defining our own rollback here because we're only running local commands,
      # and the on_rollback { } capistrano features are only intended for remote failures.
      rollback = lambda { 
        puts "rollback invoked!"
        cmd = <<-CMD
          rm -f #{remote_backup_file} &&
          #{unzip} #{local_backup_file}.#{zip_ext} && 
          #{mysql_str} < #{local_backup_file} &&
          rm -f #{local_backup_file}
        CMD
        #system("rm -f #{local_db_backup_file} && #{zip} #{application}-#{from}-db.sql")
        #system(cmd.strip)
        puts "trying to rollback with: #{cmd.strip}"
      }
      
      puts "\033[1;41m Restoring database backup to #{env} environment \033[0m"

      # local
      cmd = ""
      if store_dev_backups
        cmd << <<-CMD
          mkdir -p #{tmp_dir} && 
          #{mysql_dump} | #{zip} > #{local_backup_file}.#{zip_ext} && 
        CMD
      end
      cmd << <<-CMD
        #{unzip} -c #{remote_backup_file}.#{zip_ext} > #{remote_backup_file} &&
        #{mysql_str} < #{remote_backup_file} && 
        rm -f #{remote_backup_file}
      CMD
      #puts "running #{cmd.strip}"
      ret = system(cmd.strip)
      if $? != 0
        rollback.call
      end
      
      # Notify user if :tmp_dir is too large
      util::tmp::check
    end
    
    desc <<-DESC
      [capistrano-extensions]: Downloads a tarball of shared content (identified by the :shared_content and 
      :content_directories properties) from a deployable environment (RAILS_ENV) to the local filesystem.
    DESC
    task :backup_content do
      folders = ["content"] + shared_content.keys
      
      run "cd #{shared_path} && tar czf #{shared_path}/content_backup.tar.#{zip_ext} #{folders.join(' ')}"
      
      #run "cd #{content_path} && tar czf #{shared_path}/content_backup.tar.#{zip_ext} *"
      download("#{shared_path}/content_backup.tar.#{zip_ext}", "#{local_content_backup_dir}.tar.#{zip_ext}")
      run "rm -f #{shared_path}/content_backup.tar.#{zip_ext}"
    end
    
    desc <<-DESC
      [capistrano-extensions]: Restores the backed up content (evn var FROM specifies which environment
      was backed up, defaults to RAILS_ENV) to the local development environment app
    DESC
    task :restore_content do
      from = ENV['FROM'] || rails_env
      
      local_dir = local_content_backup_dir(:env => from)
      system "mkdir -p #{local_dir}"
      system "tar xzf #{local_dir}.tar.#{zip_ext} -C #{local_dir}"

      shared_content.each_pair do |remote, local|
        system "rm -rf #{local} && mv #{local_dir}/#{remote} #{local}"
      end
      
      content_directories.each do |public_dir|
        system "rm -rf public/#{public_dir}"
        system "mv #{local_dir}/content/#{public_dir} public/"
      end

      system "rm -rf #{local_dir}"
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
      [capistrano-extensions]: Ensure that a fresh remote data dump is retrieved before syncing to the local environment.
    DESC
    task :resync_db do
      util::tmp::clean_remote
      sync_db
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

def current_timestamp
  @current_timestamp ||= Time.now.to_i
end

def local_db_backup_file(args = {})
  env = args[:env] || rails_env
  "#{tmp_dir}/#{application}-#{env}-db-#{current_timestamp}.sql"
end

def local_db_backup_glob(args = {})
  env = args[:env] || rails_env
  "#{tmp_dir}/#{application}-#{env}-db-*.sql.#{zip_ext}"
end

def local_content_backup_dir(args={})
  env = args[:env] || rails_env
  "#{tmp_dir}/#{application}-#{env}-content-#{current_timestamp}"
end