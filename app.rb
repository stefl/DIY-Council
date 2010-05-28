require "rubygems"
require "bundler"

Bundler.setup

gem     "rack"
require "rack"

gem     "sinatra", "=1.0"
require "sinatra/base"

gem     "haml", "=2.2.21"
require "haml"
require "sass"

gem     "rack-flash", "=0.1.1"
require "rack-flash"

gem     "yajl-ruby", "=0.7.5"
require 'yajl/json_gem'

gem     "sinatra-respond_to", "=0.4.0"
require "sinatra/respond_to"

gem     "chronic", "=0.2.3"
require "chronic"

gem     "sinatra-outputbuffer", "=0.1.0"
require "sinatra/outputbuffer"

gem     "memcached"
require "memcached"

require "yaml"
require "cgi"

class CostSavingExercise < Sinatra::Base
  set :root, File.dirname(__FILE__)
  set :app_file, __FILE__
  set :views, "#{File.dirname(__FILE__)}/views"
  set :logging, true
  
  enable :methodoverride
  use Rack::Session::Cookie, :secret => "mmmmmmm, data"
  use Rack::Flash, :sweep => true
  
  helpers Sinatra::OutputBuffer::Helpers
  register Sinatra::RespondTo
  
  get "/" do
    @page_title = "DIY Council"
    haml :home
  end
  
  get '/css/:file' do
    response.headers['Cache-Control'] = "public, max-age=#{60*60}"
    respond_to do |wants|
      wants.css { sass "sass/#{params[:file]}".to_sym }
    end
  end
end