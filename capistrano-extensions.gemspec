# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{capistrano-extensions}
  s.version = "0.1.5"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["John Trupiano"]
  s.date = %q{2008-11-09}
  s.default_executable = %q{capsync}
  s.description = %q{A base set of Capistrano extensions-- aids with the file_column plugin, the GemInstaller gem, multiple deployable environments, logfile helpers, and database/asset synchronization from production to local environment}
  s.email = %q{jtrupiano@gmail.com}
  s.executables = ["capsync"]
  s.extra_rdoc_files = ["History.txt", "Manifest.txt", "README.txt"]
  s.files = ["History.txt", "Manifest.txt", "README.txt", "Rakefile", "bin/capsync", "capistrano-extensions.gemspec", "lib/capistrano-extensions.rb", "lib/capistrano-extensions/configuration.rb", "lib/capistrano-extensions/db_server.rb", "lib/capistrano-extensions/db_sync.rb", "lib/capistrano-extensions/deploy.rb", "lib/capistrano-extensions/geminstaller_dependency.rb", "lib/capistrano-extensions/version.rb"]
  s.has_rdoc = true
  s.homepage = %q{http://github.com/jtrupiano/capistrano-extensions}
  s.rdoc_options = ["--main", "README.txt"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{johntrupiano}
  s.rubygems_version = %q{1.3.1}
  s.summary = %q{A base set of Capistrano extensions-- aids with the file_column plugin, the GemInstaller gem, multiple deployable environments, logfile helpers, and database/asset synchronization from production to local environment}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<capistrano>, [">= 2.5.0"])
      s.add_runtime_dependency(%q<geminstaller>, [">= 0.4.5"])
      s.add_development_dependency(%q<hoe>, [">= 1.8.2"])
    else
      s.add_dependency(%q<capistrano>, [">= 2.5.0"])
      s.add_dependency(%q<geminstaller>, [">= 0.4.5"])
      s.add_dependency(%q<hoe>, [">= 1.8.2"])
    end
  else
    s.add_dependency(%q<capistrano>, [">= 2.5.0"])
    s.add_dependency(%q<geminstaller>, [">= 0.4.5"])
    s.add_dependency(%q<hoe>, [">= 1.8.2"])
  end
end
