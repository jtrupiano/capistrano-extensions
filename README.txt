= capistrano-extensions

* http://github.com/jtrupiano/capistrano-extensions

== DESCRIPTION/FEATURES:

This gem provides a base set of Capistrano extensions including the following:
  * a new :gemfile RemoteDependency type
  * tasks/helpers for handling public asset folders (e.g. created by the file_column plugin)
  * tasks/helpers for auto-syncing server gems (via integration with Chad Wooley's GemInstaller gem)
  * helpers for dealing with multiple deployable environments (e.g. staging, prodtest, production)
  * tasks for working with remote logfiles
  * tasks for database/asset synchronization from production back to local environments

For a detailed exploration of these features, check out the wiki: http://github.com/jtrupiano/capistrano-extensions/wikis/home

== SYNOPSIS:

  FIX (code sample of usage)

== REQUIREMENTS:

* Capistrano >= 2.4.3
* GemInstaller = 0.4.3

== INSTALL:

* sudo gem install capistrano-extensions

== LICENSE:

(The MIT License)

Copyright (c) 2008 FIX

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
