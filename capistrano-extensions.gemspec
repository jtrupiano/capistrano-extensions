# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{capistrano-extensions}
  s.version = "0.1.9"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["John Trupiano"]
  s.date = %q{2009-08-12}
  s.description = %q{A base set of Capistrano extensions-- aids with the file_column plugin, the GemInstaller gem, multiple deployable environments, logfile helpers, and database/asset synchronization from production to local environment}
  s.email = %q{jtrupiano@gmail.com}
  s.executables = ["capistrano-extensions-sync-content", "capistrano-extensions-sync-db"]
  s.extra_rdoc_files = [
    "README.rdoc"
  ]
  s.files = [
    ".gitignore",
     "History.txt",
     "ISSUES.txt",
     "MIT-LICENSE",
     "README.rdoc",
     "Rakefile",
     "TODO",
     "VERSION.yml",
     "bin/capistrano-extensions-sync-content",
     "bin/capistrano-extensions-sync-db",
     "capistrano-extensions.gemspec",
     "lib/capistrano-extensions.rb",
     "lib/capistrano-extensions/deploy.rb",
     "lib/capistrano-extensions/geminstaller_dependency.rb",
     "lib/capistrano-extensions/recipes/content_sync.rb",
     "lib/capistrano-extensions/recipes/db_sync.rb"
  ]
  s.homepage = %q{http://github.com/jtrupiano/capistrano-extensions}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{johntrupiano}
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{A base set of Capistrano extensions-- aids with the file_column plugin, the GemInstaller gem, multiple deployable environments, logfile helpers, and database/asset synchronization from production to local environment}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<capistrano>, ["~> 2.5.5"])
      s.add_runtime_dependency(%q<geminstaller>, ["~> 0.5.1"])
    else
      s.add_dependency(%q<capistrano>, ["~> 2.5.5"])
      s.add_dependency(%q<geminstaller>, ["~> 0.5.1"])
    end
  else
    s.add_dependency(%q<capistrano>, ["~> 2.5.5"])
    s.add_dependency(%q<geminstaller>, ["~> 0.5.1"])
  end
end
