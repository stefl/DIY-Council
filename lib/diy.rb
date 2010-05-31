require 'rubygems'
require 'weary'
require 'yajl'
require 'readability'
require 'open-uri'
require 'feed_detector'
require 'extractomatic'
require 'cgi'
require 'pp'
require 'similarity'

YAHOO_BOSS_APP_ID = "7gATyJ7V34FoqrIuRvHAAwMYi_L7gp2ZRFAoTP5sZzQlsNzmC1mjv.2yfvzITyWAhK0INaBA"

module DIY
  
  def self.titleize title, council
    council_name = council["name"]
    separator = nil
    common_separators = [" - ", ": ", " | ", ". ", " :: "]
    common_separators.each{|sep| separator = sep if title.include?(sep)}
    if separator
      items = title.split(separator)
      if(items.first.similarity(council_name) > 0.5)
        items.delete_at(0)
      elsif(items.last.similarity(council_name) > 0.5)
        items.delete_at(items.size - 1)
      end
      items.join(" | ")
    else
      title
    end
  end
  
  def self.urlize url, council
    
  end
  
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
      @services ||= Weary.get("http://openlylocal.com/services.json?council_id=#{council_id}").perform.parse.map{|a| Service.new(a["service"], self)}
    end
    
    def rss_feed_url
      @rss_feed_url ||= FeedDetector.fetch_feed_url(@data["url"])
    end
    
    def rss_feed
      nil #@rss_feed ||= Weary.get(rss_feed_url).perform.parse.first.last["channel"]["item"] if rss_feed_url  rescue []    
    end
    
    def tag
      #guess a tag that might be used on flickr for this council based on its url
      t = @data["url"].gsub("http://","")
      t = t.gsub("www.","")
      t = t.gsub(".gov.uk","")
      t = t.gsub("/","")
      t = t.gsub(".","")
      "#{t}"
    end
    
    def flickr_feed
      @flickr_feed ||= Weary.get("http://www.degraeve.com/flickr-rss/rss.php?tags=#{tag}&tagmode=all&sort=date-posted-desc&num=25").perform.parse.first.last["channel"]["item"] rescue nil
    end
    
    def suggest terms
      results = search terms
      STDERR.puts results.inspect
      results.map{|a| {:id=>a.title, :label=>a.title, :value=>a.url}}
    end
    
    def search terms 
      terms = self.class.clean_terms terms
      results = Weary.get("http://boss.yahooapis.com/ysearch/web/v1/site:#{@data["url"]}%20#{terms}?appid=#{YAHOO_BOSS_APP_ID}&format=json").perform.parse
      pages = results.first.last["resultset_web"].map{|a| Page.new(a, self)}
      services.select{|a| a["title"].downcase.include?(terms)} + pages
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
    
    def self.clean_terms terms
      if(terms.include?("&"))
        terms = terms.split("&")[0]
      end
      if(terms.include?("?"))
        terms = terms.split("?")[0]
      end
      CGI.escape(terms)
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
  
  class Page
    attr_accessor :data
    attr_accessor :council

    def [](ind)
      @data[ind]
    end
    
    def initialize(o, c)
      self.data = o
      self.council = c
    end
    
    def extract
      Extractomatic.get(self.data["url"])
    end
    
    def readable
      Readability::Document.new(open(self.data["url"]).read)
    end
    
    def title
      @title ||= DIY.titleize(@data["title"], council)
    end
    
    def url
      @data["url"]
    end
    
    def diy_url
      DIY.urlize(@data["url"], council)
    end
    
    def to_json
      "{'title':#{title},'url':#{url}}"
    end
    
    def method_missing(method_name)
      @data[method_name]
    end
  end
  
  class Service
    attr_accessor :data
    attr_accessor :council

    def [](ind)
      @data[ind]
    end
    
    def initialize(o,c)
      self.data = o
      self.council = c
    end
    
    def extract
      Extractomatic.get(self.data["url"])
    end
    
    def readable
      Readability::Document.new(open(self.data["url"]).read)
    end
    
    def title
      @title ||= DIY.titleize(@data["title"], council)
    end
    
    def url
      @data["url"]
    end
    
    def diy_url
      DIY.urlize(@data["url"], council)
    end
    
    def to_json
      "{'title':#{title},'url':#{url}}"
    end
    
    def method_missing(method_name)
      @data[method_name]
    end
  end
end