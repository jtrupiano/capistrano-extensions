namespace :remote do
  desc <<-DESC
    [capistrano-extensions] Uploads the backup file downloaded from local:backup_db (specified via the FROM env variable), 
    copies it to the remote environment specified by RAILS_ENV, and imports (via mysql command line tool) it back into the 
    remote database.
  DESC
  task :restore_db, :roles => :db do
    env = ENV['FROM'] || 'production'
    
    puts "\033[1;41m Restoring database backup to #{rails_env} environment \033[0m"
    if deployable_environments.include?(rails_env.to_sym)
      generate_remote_db_backup if store_remote_backups
      
      # remote environment
      local_backup_file = local_db_backup_file(:timestamp => most_recent_local_backup(env, 'db'), :env => env) + ".#{zip_ext}"
      remote_file       = "#{shared_path}/restore_#{env}_db.sql"
      
      if !File.exists?(local_backup_file)
        puts "Could not find backup file: #{local_backup_file}"
        exit 1
      end
      upload(local_backup_file, "#{remote_file}.#{zip_ext}")

      pass_str = pluck_pass_str(db)
      run "#{unzip} -c #{remote_file}.#{zip_ext} > #{remote_file}"
      run "cd #{current_path} && rake RAILS_ENV=#{rails_env} db:drop db:create"
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
end

namespace :local do
  desc <<-DESC
    [capistrano-extensions]: Backs up deployable environment's database (identified by the 
    RAILS_ENV environment variable, which defaults to 'production') and copies it to the local machine
  DESC
  task :backup_db, :roles => :db do 
    
    # sort by last alphabetically (forcing the most recent timestamp to the top)
    files = retrieve_local_files(rails_env, 'db')

    if files.empty?
      # pull it from the server
      generate_remote_db_backup unless server_cache_valid?(db_backup_zip_file)
      system "mkdir -p #{tmp_dir}"
      download(db_backup_zip_file, "#{local_db_backup_file}.#{zip_ext}")
    else
      # set us up to use our local cache
      @current_timestamp = files.first.to_i # actually has the extension hanging off of it, but shouldn't be a problem
    end
  end
      
  desc <<-DESC
    [capistrano-extensions] Untars the backup file downloaded from local:backup_db (specified via the FROM env 
    variable, which defalts to RAILS_ENV), and imports (via mysql command line tool) it back into the database 
    defined in the RESTORE_ENV env variable (defaults to development).
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
      rake RAILS_ENV=#{env} db:drop db:create &&
      #{mysql_str} < #{remote_backup_file} && 
      rm -f #{remote_backup_file}
    CMD
    system(cmd.strip)
    
    # Notify user if :tmp_dir is too large
    util::tmp::check
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
  
end

def db_backup_file
  "#{shared_path}/backup_#{rails_env}_db.sql"
end

def db_backup_zip_file
  "#{db_backup_file}.#{zip_ext}"
end

def generate_remote_db_backup
  pass_str = pluck_pass_str(db)
  run "mysqldump --add-drop-database -u#{db['username']} #{pass_str} #{db['database']} > #{db_backup_file}"
  run "rm -f #{db_backup_zip_file} && #{zip} #{db_backup_file} && rm -f #{db_backup_file}"
end
