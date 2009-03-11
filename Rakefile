# -*- ruby -*-

require 'rubygems'
require 'hoe'
require './lib/capistrano-extensions.rb'
require "./lib/capistrano-extensions/version"

PKG_NAME      = "capistrano-extensions"
PKG_BUILD     = ENV['PKG_BUILD'] ? '.' + ENV['PKG_BUILD'] : ''
version = CapistranoExtensions::Version::STRING.dup
if ENV['SNAPSHOT'].to_i == 1
  version << "." << Time.now.utc.strftime("%Y%m%d%H%M%S")
end
PKG_VERSION   = version
PKG_FILE_NAME = "#{PKG_NAME}-#{PKG_VERSION}"

Hoe.new(PKG_NAME, PKG_VERSION) do |p|
  p.rubyforge_name = 'johntrupiano' # if different than lowercase project name
  p.developer('John Trupiano', 'jtrupiano@gmail.com')
  p.name = PKG_NAME
  p.version = PKG_VERSION
  #p.platform = Gem::Platform::RUBY
  p.author = "John Trupiano"
  p.email = "jtrupiano@gmail.com"
  p.description = %q(A base set of Capistrano extensions-- aids with the file_column plugin, the GemInstaller gem, multiple deployable environments, logfile helpers, and database/asset synchronization from production to local environment)
  p.summary = p.description # More details later??
  p.remote_rdoc_dir = PKG_NAME # Release to /PKG_NAME
  #  p.changes = p.paragraphs_of('CHANGELOG', 0..1).join("\n\n")
  p.extra_deps << ["capistrano", "~> 2.5.5"]
  p.extra_deps << ["geminstaller", "~> 0.5.1"]
  p.need_zip = true
  p.need_tar = false
end

# vim: syntax=Ruby
