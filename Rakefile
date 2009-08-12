require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

gem 'jeweler', '~> 1.2.0'
require 'jeweler'
Jeweler::Tasks.new do |gem|
  gem.name = "capistrano-extensions"
  gem.summary = %q(A base set of Capistrano extensions-- aids with the file_column plugin, the GemInstaller gem, multiple deployable environments, logfile helpers, and database/asset synchronization from production to local environment)
  gem.authors = ["John Trupiano"]
  gem.email = "jtrupiano@gmail.com"
  gem.homepage = "http://github.com/jtrupiano/capistrano-extensions"
  gem.description = %q(A base set of Capistrano extensions-- aids with the file_column plugin, the GemInstaller gem, multiple deployable environments, logfile helpers, and database/asset synchronization from production to local environment)

  gem.rubyforge_project = "johntrupiano"

  gem.add_dependency "capistrano", "~> 2.5.5"
  gem.add_dependency "geminstaller", "~> 0.5.1"
end

# preprare for 
Jeweler::RubyforgeTasks.new do |rubyforge|
  rubyforge.remote_doc_path = "capistrano-extensions"
  rubyforge.doc_task = "rdoc"
end

desc 'Default: run unit tests.'
task :default => :test

desc 'Test the capistrano-extensions plugin.'
Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
end

desc 'Generate documentation'
Rake::RDocTask.new do |rdoc|
  config = YAML.load(File.read('VERSION.yml'))
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "capistrano-extensions #{config[:major]}.#{config[:minor]}.#{config[:patch]}"
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
