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
require 'open-uri'

$: << "lib"

require 'readability'
require "openlylocal"

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
    
    @councils = OpenlyLocal::Council.all rescue []
    
    haml :home
  end
  
  post "/councils/find_by_postcode" do
    @council = OpenlyLocal::Council.find_by_postcode(params[:postcode])
    STDERR.puts @council.inspect
    redirect "/councils/#{@council["id"]}"
  end

  get "/councils/:council_id" do |council_id|
    @council = OpenlyLocal::Council.get(council_id)
    @services = @council.services
    @rss_feed = @council.rss_feed
    haml :council
  end
  
  get "/councils/:council_id/services/:service_id" do |council_id,service_id|
    @council = OpenlyLocal::Council.get(council_id)
    @services = @council.services
    
    @service = @services.select{|a| a["id"].to_s == service_id.to_s}.first
    STDERR.puts @service.inspect
    
    haml :service
  end
  
  get /councils\/(.*)\/page\/(.*)/ do
    @council = OpenlyLocal::Council.get(params[:captures][0])
    base_url = URI.parse(@council.url.strip('/'))
    res = Net::HTTP.start(feed_base_url.host, feed_base_url.port) {|http|
      http.get @council.url.strip('/') + "/" + params[:captures][1]
    }
    res.body
  end
  
  post "/councils" do
    redirect "/councils/#{params["council"]}"
  end
  
  get '/css/:file' do
    response.headers['Cache-Control'] = "public, max-age=#{60*60}"
    respond_to do |wants|
      wants.css { sass "sass/#{params[:file]}".to_sym }
    end
  end
end