require 'rubygems'

gem 'dm-core', '>=0.9.5'
gem 'git', '>=1.0.5'
require 'dm-core'
require 'git'
begin
  require Pathname('json/ext')
rescue LoadError
  require Pathname('json/pure')
end

dir = Pathname(__FILE__).dirname.expand_path / 'dm-gitdb'
require dir / 'adapters' / 'data_objects_adapter'
require dir / 'gitdb'
