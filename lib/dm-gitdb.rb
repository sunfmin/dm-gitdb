require 'rubygems'

gem 'dm-core', '>=0.9.6'
gem 'dm-serializer', '>=0.9.6'
require 'dm-core'
require 'dm-serializer'
require 'git'

dir = Pathname(__FILE__).dirname.expand_path / 'dm-gitdb'
require dir / 'adapters' / 'data_objects_adapter'
require dir / 'gitdb'


