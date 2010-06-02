require 'rubygems'
require "spec"
require 'mocha'
require 'dm-core'

$: << "../lib"
require 'diy'

DataMapper.setup(:default, "postgres://postgres:postgres@localhost:5432/diycouncil_test")
DataMapper.auto_migrate!

Spec::Runner.configure do |config|
  
  config.mock_with :mocha  

  config.before(:each) do

  end
  config.after(:all) do
    
  end

end
