require 'yaml'
require 'capistrano/recipes/deploy/script_helpers'
require 'capistrano/recipes/deploy/variable_defaults'

module Capistrano
  class Configuration
    include Capistrano::Deploy::ScriptHelpers
    include Capistrano::Deploy::VariableDefaults
    
    # override initialize
    alias_method :initialize_without_capistrano_extensions, :initialize
    def initialize_with_capistrano_extensions(env)
      #ENV['RAILS_ENV'] = env # this feels _very_ dangerous
      initialize_without_capistrano_extensions # Capistrano::Configuration.new
      load do
        load "deploy"           # capistrano's deploy script    -- should be more explicit
        set(:rails_env, env)
        load "config/deploy.rb" # consuming app's deploy script -- should be more explicit
      end
      @local = self.local_environments.map.include?(env.to_sym)
    end
    alias_method :initialize, :initialize_with_capistrano_extensions
    
    def to_db_server
      #db, user, pass = cnf['database'], cnf['username'], cnf['password']
      #puts("[***********]: #{self.fetch(:rails_env)}: local = #{local?}. Setting db, user, pass to #{db}, #{user}, #{pass}")
      env = self.fetch(:rails_env)
      DbServer.new(self, env, @local)
    end
    
  end
end
