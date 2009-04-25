namespace :remote do
  desc <<-DESC
    [capistrano-extensions]: Uploads the backup file downloaded from local:backup_content (specified via the 
    FROM env variable), copies it to the remote environment specified by RAILS_ENV, and unpacks it into the 
    shared/ directory.
  DESC
  task :restore_content do
    from = ENV['FROM'] || 'production'
    
    if deployable_environments.include?(rails_env.to_sym)
      generate_remote_content_backup if store_remote_backups
      
      local_backup_file = local_content_backup_dir(:timestamp => most_recent_local_backup(from, 'content'), :env => from) + ".tar.#{zip_ext}"
      remote_dir        = "#{shared_path}/restore_#{from}_content"
      remote_file       = "#{remote_dir}.tar.#{zip_ext}"
      
      if !File.exists?(local_backup_file)
        puts "Could not find backup file: #{local_backup_file}"
        exit 1
      end
      
      upload(local_backup_file, "#{remote_file}")
      remote_dirs = [content_dir] + shared_content.keys
      
      run("cd #{shared_path} && rm -rf #{remote_dirs.join(' ')} && tar xzf #{remote_file} -C #{shared_path}/")
    end
  end
  
  desc <<-DESC
    [capistrano-extensions]: Backs up remote server's shared content and restores it to a separate remote server.
    $> cap remote:sync_content FROM=production TO=staging
  DESC
  task :sync_content do
    system("capistrano-extensions-sync-content #{ENV['FROM'] || 'production'} #{ENV['TO'] || 'staging'}")
  end
end

namespace :local do
  desc <<-DESC
    [capistrano-extensions]: Downloads a tarball of shared content (identified by the :shared_content and 
    :content_directories properties) from a deployable environment (RAILS_ENV) to the local filesystem.
  DESC
  task :backup_content do
    system("mkdir -p #{tmp_dir}")
    # sort by last alphabetically (forcing the most recent timestamp to the top)
    files = retrieve_local_files(rails_env, 'content')
    
    if files.empty?
      # pull it from the server
      generate_remote_content_backup unless server_cache_valid?(content_backup_file)
      download(content_backup_file, "#{local_content_backup_dir}.tar.#{zip_ext}")
    else
      # set us up to use our local cache
      @current_timestamp = files.first.to_i # actually has the extension hanging off of it, but shouldn't be a problem
    end      
    # Notify user if :tmp_dir is too large
    util::tmp::check
  end
  
  desc <<-DESC
    [capistrano-extensions]: Restores the backed up content (env var FROM specifies which environment
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
    [capistrano-extensions]: Wrapper for local:backup_content and local:restore_content
    $> cap local:sync_content RAILS_ENV=production RESTORE_ENV=development
  DESC
  task :sync_content do
    transaction do
      backup_content
      restore_content
    end
  end
end

def content_backup_file
  "#{shared_path}/backup_#{rails_env}_content.tar.#{zip_ext}"
end

def generate_remote_content_backup
  folders = [content_dir] + shared_content.keys
  run "cd #{shared_path} && tar czf #{content_backup_file} #{folders.join(' ')}"
end
