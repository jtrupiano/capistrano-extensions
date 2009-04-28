require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "capistrano-extensions"
    gem.rubyforge_project = "johntrupiano"
    gem.summary = %q(A base set of Capistrano extensions-- aids with the file_column plugin, the GemInstaller gem, multiple deployable environments, logfile helpers, and database/asset synchronization from production to local environment)
    gem.email = "jtrupiano@gmail.com"
    gem.homepage = "http://github.com/jtrupiano/capistrano-extensions"
    gem.description = %q(A base set of Capistrano extensions-- aids with the file_column plugin, the GemInstaller gem, multiple deployable environments, logfile helpers, and database/asset synchronization from production to local environment)
    gem.authors = ["John Trupiano"]
    gem.add_dependency "capistrano", "~> 2.5.5"
    gem.add_dependency "geminstaller", "~> 0.5.1"
  end
rescue LoadError
  puts "Jeweler, or one of its dependencies, is not available. Install it with: sudo gem install jeweler"
end

desc 'Default: run unit tests.'
task :default => :test

desc 'Test the capistrano-extensions plugin.'
Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
end

desc 'Generate documentation for the sanitize_email plugin.'
Rake::RDocTask.new do |rdoc|
  config = YAML.load(File.read('VERSION.yml'))
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "sanitize_email #{config[:major]}.#{config[:minor]}.#{config[:patch]}"
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

# Rubyforge documentation task
begin
  require 'rake/contrib/sshpublisher'
  namespace :rubyforge do
    
    desc "Release gem and RDoc documentation to RubyForge"
    task :release => ["rubyforge:release:gem", "rubyforge:release:docs"]
    
    namespace :release do
      desc "Publish RDoc to RubyForge."
      task :docs => [:rdoc] do
        config = YAML.load(
          File.read(File.expand_path('~/.rubyforge/user-config.yml'))
        )

        host = "#{config['username']}@rubyforge.org"
        remote_dir = "/var/www/gforge-projects/johntrupiano/capistrano-extensions/"
        local_dir = 'rdoc'

        Rake::SshDirPublisher.new(host, remote_dir, local_dir).upload
      end
    end
  end
rescue LoadError
  puts "Rake SshDirPublisher is unavailable or your rubyforge environment is not configured."
end
