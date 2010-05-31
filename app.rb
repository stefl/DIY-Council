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
require "diy"

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
  
  before do
    @show_page_title = true
  end
  
  get "/" do
    @councils = DIY::Council.all rescue []
    
    haml :home
  end
  
  get "/members/:member_id" do |member_id|
    content_type :html
    @member = DIY::Member.get(member_id)
    haml :member, :layout=>false
  end
  
  post "/find_by_postcode" do
    begin
      @council = DIY::Council.find_by_postcode(params[:postcode])
      STDERR.puts @council.inspect
      redirect "/#{@council.slug}"
    rescue
      flash[:errors] = "Sorry - I can't find the council for that postcode"
      redirect "/"
    end
  end

  get "/:council_slug" do |council_slug|
    @council = DIY::Council.from_slug(council_slug)
    raise Sinatra::NotFound if @council.blank?
    @services = @council.services
    @rss_feed = @council.rss_feed
    
    haml :council
  end
  
  get "/:council_slug/contact" do |council_slug|
    @council = DIY::Council.from_slug(council_slug)
    @page_title = "Contact"
    haml :contact
  end
  
  get "/:council_slug/near_me" do |council_slug|
    @council = DIY::Council.from_slug(council_slug)
    @page_title = "Find things near me"
    haml :near_me
  end
  
  get "/:council_slug/suggest" do |council_slug|
    @council = DIY::Council.from_slug(council_slug)
    STDERR.puts params[:term]
    results = @council.suggest(CGI.unescape(params[:term]))
    content_type :json
    results.to_json
  end
  
  get "/:council_slug/services/:service_id" do |council_slug,service_id|
    @council = DIY::Council.from_slug(council_slug)
    @services = @council.services
    
    @service = @services.select{|a| a["id"].to_s == service_id.to_s}.first
    STDERR.puts @service.inspect
    @page_title = "#{@service.title}"
    haml :service
  end
  
  get "/:council_slug/page" do |council_slug|
    @council = DIY::Council.from_slug(council_slug)
    @page = @council.get_page(params[:url])
    @page_title = "#{@page.title}"
    haml :page
  end
  
  get "/:council_slug/about" do |council_slug|
    @council = DIY::Council.from_slug(council_slug)
    haml :about
  end
  
  post "/councils" do
    redirect "/#{params["council"]}"
  end
  
  get '/favicon' do
    redirect '/images/favicon.ico'
  end
  
  get '/css/:file' do
    response.headers['Cache-Control'] = "public, max-age=#{60*60}"
    respond_to do |wants|
      wants.css { sass "sass/#{params[:file]}".to_sym }
    end
  end
end