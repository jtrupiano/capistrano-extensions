(in /Users/john/projects/capistrano-extensions)
Gem::Specification.new do |s|
  s.name = %q{capistrano-extensions}
  s.version = "0.1.3"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["John Trupiano"]
  s.date = %q{2008-08-26}
  s.description = %q{A base set of Capistrano extensions-- aids with the file_column plugin, the GemInstaller gem, multiple deployable environments, logfile helpers, and database/asset synchronization from production to local environment}
  s.email = %q{jtrupiano@gmail.com}
  s.executables = ["capistrano-extensions-sync-content", "capistrano-extensions-sync-db"]
  s.extra_rdoc_files = ["History.txt", "Manifest.txt", "README.txt"]
  s.files = ["History.txt", "Manifest.txt", "README.txt", "Rakefile", "bin/capistrano-extensions-sync-content", "bin/capistrano-extensions-sync-db", "lib/capistrano-extensions.rb", "lib/capistrano-extensions/deploy.rb", "lib/capistrano-extensions/geminstaller_dependency.rb", "lib/capistrano-extensions/version.rb"]
  s.has_rdoc = true
  s.homepage = %q{http://github.com/jtrupiano/capistrano-extensions}
  s.rdoc_options = ["--main", "README.txt"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{capistrano-extensions}
  s.rubygems_version = %q{1.2.0}
  s.summary = %q{A base set of Capistrano extensions-- aids with the file_column plugin, the GemInstaller gem, multiple deployable environments, logfile helpers, and database/asset synchronization from production to local environment}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if current_version >= 3 then
      s.add_runtime_dependency(%q<capistrano>, [">= 2.4.3"])
      s.add_runtime_dependency(%q<geminstaller>, [">= 0.4.3"])
      s.add_development_dependency(%q<hoe>, [">= 1.7.0"])
    else
      s.add_dependency(%q<capistrano>, [">= 2.4.3"])
      s.add_dependency(%q<geminstaller>, [">= 0.4.3"])
      s.add_dependency(%q<hoe>, [">= 1.7.0"])
    end
  else
    s.add_dependency(%q<capistrano>, [">= 2.4.3"])
    s.add_dependency(%q<geminstaller>, [">= 0.4.3"])
    s.add_dependency(%q<hoe>, [">= 1.7.0"])
  end
end
