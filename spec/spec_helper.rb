require 'rubygems'
require "spec"
require 'mocha'

$: << "../lib"
require 'diy'

Spec::Runner.configure do |config|
  config.mock_with :mocha  

  config.before(:each) do

  end
  config.after(:all) do
    
  end

end
