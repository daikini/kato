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

Copyright 2008 Jonathan Younger

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
