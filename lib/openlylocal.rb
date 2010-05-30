require 'rubygems'
require 'weary'
require 'yajl'
require 'readability'
require 'open-uri'
require 'feed_detector'
require 'extractomatic'
require 'feedzirra'

module OpenlyLocal
  class Council
    
    attr_accessor :council_id
    attr_accessor :data
    
    def [](ind)
      @data[ind]
    end
    
    def initialize(id)
      self.council_id = id
    end
    
    def services
      @services ||= Weary.get("http://openlylocal.com/services.json?council_id=#{council_id}").perform.parse.map{|a| Service.new(a["service"])}
    end
    
    def rss_feed_url
      @rss_feed_url ||= FeedDetector.fetch_feed_url(@data["url"])
    end
    
    def rss_feed
      Feedzirra::Feed.fetch_and_parse(rss_feed_url) if rss_feed_url
    end
    
    def info
      @data ||= self.load
    end
    
    def load
      @data ||= Weary.get("http://openlylocal.com/councils/#{council_id}.json").perform.parse["council"]
    end
    
    def self.all
      Weary.get("http://openlylocal.com/councils.json").perform.parse.map{|a| a["council"]}
    end
    
    def self.get(id)
      council = Council.new(id)
      council.load
      council
    end
    
    def self.find_by_postcode(postcode)
      postie = Weary.get("http://openlylocal.com/areas/postcodes/#{postcode.gsub(' ', '')}.json").perform.parse["postcode"]
      STDERR.puts postie.inspect
      self.get(postie["council_id"])
    end
    
    def method_missing(method_name)
      @data[method_name]
    end
    
    def id
      @data["id"]
    end
  end
  
  class Service
    attr_accessor :data

    def [](ind)
      @data[ind]
    end
    
    def initialize(o)
      self.data = o
    end
    
    def extract
      Extractomatic.get(self.data["url"])
    end
    
    def readable
      Readability::Document.new(open(self.data["url"]).read)
    end
  end
end
