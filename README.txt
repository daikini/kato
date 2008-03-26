= kato

* http://kato.rubyforge.org

== DESCRIPTION:

Kato is a library for managing pools of Amazon EC2 servers.
It is a ruby port of the java lifeguard http://code.google.com/p/lifeguard/ library.

== FEATURES/PROBLEMS:

* Manage multiple EC2 pools
* Minimum number of instances
* Maximum number of instances
* Ramp up/down intervals

== SYNOPSIS:

  require 'rubygems'
  require 'kato'
  pool_supervisor = Kato::PoolSupervisor.new(config)
  pool_supervisor.run

== REQUIREMENTS:

* right_aws

== INSTALL:

* gem install kato

== LICENSE:

(The MIT License)

Copyright (c) 2008 Jonathan Younger

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