Gem::Specification.new do |s|
  s.name = "capistrano-extensions"
  s.version = PKG_VERSION
  s.platform = Gem::Platform::RUBY
  s.author = "John Trupiano"
  s.email = "jtrupiano@gmail.com"
  s.description = %q(A base set of Capistrano extensions-- aids with the file_column plugin, the GemInstaller gem, multiple deployable environments, logfile helpers, and database/asset synchronization from production to local environment)
  s.summary = s.description # More details later??
  s.has_rdoc = false
  s.require_paths = ["lib"]
  
  s.files = Dir.glob("{lib}/**/*") + %w(README)
  
  s.add_dependency(%q<capistrano>, [">= 2.3.0"]) # pessimistic?
end
