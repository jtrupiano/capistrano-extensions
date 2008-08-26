# GEM_SPEC = eval(File.read("#{File.dirname(__FILE__)}/#{PKG_NAME}.gemspec"))
# 
# Rake::GemPackageTask.new(GEM_SPEC) do |p|
#   p.gem_spec = GEM_SPEC
#   p.need_tar = true
#   p.need_zip = true
# end
# 
# desc "Clean up generated directories and files"
# task :clean do
#   rm_rf "pkg"
# end


# -*- ruby -*-

require 'rubygems'
require 'hoe'
require './lib/capistrano-extensions.rb'
require "./lib/capistrano-extensions/version"


PKG_NAME      = "capistrano-extensions"
PKG_BUILD     = ENV['PKG_BUILD'] ? '.' + ENV['PKG_BUILD'] : ''
PKG_VERSION   = CapistranoExtensions::Version::STRING + PKG_BUILD
PKG_FILE_NAME = "#{PKG_NAME}-#{PKG_VERSION}"


Hoe.new('capistrano-extensions', PKG_VERSION) do |p|
  # p.rubyforge_name = 'capistrano-extensionsx' # if different than lowercase project name
  # p.developer('FIX', 'FIX@example.com')
  p.name = "capistrano-extensions"
  p.version = PKG_VERSION
  #p.platform = Gem::Platform::RUBY
  p.author = "John Trupiano"
  p.email = "jtrupiano@gmail.com"
  p.description = %q(A base set of Capistrano extensions-- aids with the file_column plugin, the GemInstaller gem, multiple deployable environments, logfile helpers, and database/asset synchronization from production to local environment)
  p.summary = p.description # More details later??
  p.remote_rdoc_dir = 'capistrano-extensions' # Release to /capistrano-extensions
  #  p.changes = p.paragraphs_of('CHANGELOG', 0..1).join("\n\n")
  p.extra_deps << ["capistrano", ">= 2.4.3"]
  p.extra_deps << ["geminstaller", ">= 0.4.3"]
  p.need_zip = true
  p.need_tar = false
end

# vim: syntax=Ruby
