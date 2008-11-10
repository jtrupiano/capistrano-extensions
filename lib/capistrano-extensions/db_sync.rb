require File.join(File.dirname(__FILE__), 'db_server')

# Utility class for managing a sync operation between two DbServers.
class DbSync
  attr_reader :from_conf, :to_conf
  def initialize(from_conf, to_conf)
    @from_conf, @to_conf = from_conf, to_conf
  end
  
  def sync!
    f_db = from_conf.to_db_server
    t_db = to_conf.to_db_server

    # mysqldump >
    f_db.dump!(from_file)

    # scp
    t_db.transfer!(f_db, from_file, to_file_gz)
    
    # mysql < 
    puts "\033[1;41m Restoring #{from_conf.rails_env} database backup to #{to_conf.rails_env} database \033[0m"
    t_db.sync!(to_file)
  end
  
  private
    def from_file
      "#{from_conf.shared_path}/db_backup.sql.gz"
    end
    
    def to_file
      "#{from_conf.application}-#{from_conf.rails_env}-db.sql"
    end
    
    def to_file_gz
      "#{to_file}.gz"
    end

end