require File.join(File.dirname(__FILE__), 'rollbackable')

# Encapsulates logic of executing shell commands on a remote or local server
class DbServer
  include Rollbackable
  
  attr_reader :config, :env, :local, :db, :username, :password, :timestamp
  alias local? local
  
  def initialize(config, env, local)
    @timestamp = Time.now
    cnf = YAML.load_file(config.local_db_conf(env))[env]

    @config, @env, @local       = config, env, local
    @db, @username, @password   = cnf['database'], cnf['username'], cnf['password']
  end
    
  def dump!(file)
    puts "\033[1;41m Dumping #{config.rails_env} database \033[0m"
    run_command("#{mysql_dump_str} | gzip > #{file}")
  end
  
  def transfer!(from, from_file, to_file)
    puts "\033[1;41m Copying #{from.config.rails_env} database backup to #{config.rails_env} server \033[0m"
    cmd = "scp #{from.config.user}@#{from.config.ip}:#{from_file} #{to_file}"
    run_command(cmd)
  end

  def sync!(remote_backup_file)
    #puts "\033[1;41m Restoring #{config.rails_env} database backup to #{to.config.rails_env} database \033[0m"
    cmd = <<-CMD
      #{mysql_dump_str} | gzip > #{local_backup_file}.gz &&
      rake RAILS_ENV=#{@env} db:drop db:create &&
      gunzip -c #{remote_backup_file}.gz > #{remote_backup_file} &&
      #{mysql_str} < #{remote_backup_file} && 
      rm -f #{remote_backup_file}
    CMD
    add_rollback rollback_sync(remote_backup_file)
    run_command(cmd.strip)
  end
      
  private
    # code block to execute on failed sync
    def rollback_sync(remote_backup_file)
      lambda {
        puts "-------------- rollback invoked! -----------------"
        cmd = <<-CMD
          rm -f #{remote_backup_file} &&
          gunzip #{local_backup_file}.gz && 
          rake RAILS_ENV=#{@env} db:drop db:create &&
          #{mysql_str} < #{local_backup_file} &&
          rm -f #{local_backup_file}
        CMD
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
      "#{@config.fetch(:application)}-#{@env}-#{@timestamp.to_i}-db.bak"
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
        ret = @config.send(:system, cmd)
        if !rollback_proc.nil? && ($? != 0)
          msg = "Local error caught: #{ret}"
          put_error(msg)
          raise StandardError.new(msg)
        end
      else
        begin
          @config.run(cmd)
        rescue => ex
          put_error("Remote exception caught: #{ex.message}")
          raise ex
        end
      end
    end
    
    def put_error(msg)
      $stderr.write("[c-ext][#{config.ip}]*************: #{msg}")
      $stderr.flush
    end
  
end