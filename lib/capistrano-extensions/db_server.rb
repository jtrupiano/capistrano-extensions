class DbServer

  attr_reader :config, :local_env, :local, :db, :username, :password, :timestamp
  alias local? local
  
  def initialize(config, local_env, local, db=config.db['database'], username=config.db['username'], password=config.db['password'])
    @config, @local_env, @local, @db, @username, @password = config, local_env, local, db, username, password
    @timestamp = Time.now
  end
    
  def transfer_to!(to)
    from_file = "#{config.shared_path}/db_backup.sql.gz"
    to_file   = "#{config.application}-#{config.rails_env}-db.sql.gz"

    puts "\033[1;41m Dumping #{config.rails_env} database \033[0m"
    dump!(from_file)

    to.send(:transfer!, self, from_file, to_file)
    
    puts "\033[1;41m Restoring #{config.rails_env} database backup to #{to.config.rails_env} database \033[0m"
    to.send(:sync!, to_file)
  end
      
  private
    def dump!(file)
      run_command("#{mysql_dump_str} | gzip > #{file}.gz")
    end
    
    def transfer!(from, from_file, to_file)
      cmd = "scp #{from.config.user}@#{from.config.ip}:#{from_file} #{to_file}"
      puts "\033[1;41m Copying #{from.config.rails_env} database backup to #{config.rails_env} server \033[0m"
      run_command(cmd)  
    end

    def sync!(remote_backup_file)
      cmd = <<-CMD
        #{mysql_dump_str} | gzip > #{local_backup_file}.gz &&
        rake RAILS_ENV=#{@local_env} db:drop db:create &&
        gunzip -c #{remote_backup_file}.gz > #{remote_backup_file} &&
        #{mysql_str} < #{remote_backup_file} && 
        rm -f #{remote_backup_file}
      CMD
      puts cmd
      run_command(cmd.strip, rollback_sync(remote_backup_file))
    end
  
    # code block to execute on failed sync
    def rollback_sync(remote_backup_file)
      lambda {
        puts "rollback invoked!"
        cmd = <<-CMD
          rm -f #{remote_backup_file} &&
          gunzip #{local_backup_file}.gz && 
          rake RAILS_ENV=#{@local_env} db:drop db:create &&
          #{mysql_str} < #{local_backup_file} &&
          rm -f #{local_backup_file}
        CMD

        puts "trying to rollback with: #{cmd.strip}"
        run_command(cmd.strip)
      }
    end
    
    # mysql command w/ username/password/database
    def mysql_str
      "mysql -u#{@username} #{pass_str} #{@db}"
    end
    
    # mysqldump command w/ username/password/database
    def mysql_dump_str
      "mysqldump -u#{@username} #{pass_str} #{@db}"
    end
    
    # where we'll store the local backup (in case of rollback)
    def local_backup_file
      "#{@config.fetch(:application)}-#{@local_env}-#{@timestamp.to_i}-db.bak"
    end
    
    # builds the password chunk of command-line mysql calls.
    # when password is empty, we omit it from the command-line calls.
    def pass_str
      return "" if @password.nil?
      "-p#{@password.gsub('$', '\$')}"
    end
    
    # wrapper for run/system -- branches on response to local? -- takes an optional rollback proc
    def run_command(cmd, rollback_proc=nil)
      puts "[c-ext][#{config.ip}]: #{cmd}"
      # is this correct??
      if local?
        @config.send(:system, cmd)
        rollback_proc.call if !rollback_proc.nil? && ($? != 0)
      else
        begin
          @config.run(cmd)
        rescue
          rollback_proc.call if !rollback_proc.nil?
        end
      end
    end
  
end