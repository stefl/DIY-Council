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
    return "" if  title.blank?
    council_name = council["name"]
    separator = nil
    common_separators = [" - ", " • ", " &bull; ", ": ", " | ", ". ", " :: "]
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
  
  def self.add_telephone_microformats(base)
    base.gsub(/^(((\(?\+44\)?(\(0\))?\s?\d{4}|\(?\+44\)?(\(0\))?\s?(0)\s?\d{3}|\(?0\d{4}\)?)\s?\d{3}\s?\d{3})|((\(?\+44\)?(\(0\))?\s?\d{3}|\(?0\d{3}\)?)\s?(\d{3}\s?\d{4}|\d{4}\s?\d{4}))|((\(?\+44\)?(\(0\))?\s?\d{2}|\(?0\d{2}\)?)\s?\d{4}\s?\d{4}))(\s?\#(\d{4}|\d{3}|\d{5}))?$/) {|s| "<span class='telephone'>" + s.gsub(/[\(\)]/,"").gsub("(0)","").gsub("+44","0").gsub(/^00/,'0').gsub(' ','').to_s + "</span>"}
  end
  
  def self.reroute_links(base, council)
    r = rebase_links(base,council)
    r.gsub(/href\=[\"\']/) {|s| s + "/councils/#{council.slug}/page?url="  }
  end
  
  def self.rebase_links(base, council)
    base.gsub(/href\=[\"\'](\/)/){|a| 
    STDERR.puts a
    a.chomp('/') + council.url.chomp('/') + "/" }
  end
  
  class Council
    
    attr_accessor :council_id
    attr_accessor :data
    
    def [](ind)
      @data[ind]
    end
    
    def slug
      @slug ||= @data["name"].downcase.gsub("&", "and").gsub("royal borough of","").gsub("london borough of","").gsub("district","").gsub("council of the","").gsub("city and county of", "").gsub("city of", "").gsub("city","").gsub("metropolitan","").gsub("county","").gsub("borough of", "").gsub(" borough"," ").gsub("council", "").gsub("'","").strip.gsub(" ","_").gsub("-","_")
    end
    
    def self.from_slug the_slug
      found = nil
      Council.all.each do |c|
        unless found
          if the_slug == c.slug
            found = c
          end
        end
      end
      nil
      found unless found.blank?
    end
    
    def initialize(id, the_data = nil)
      self.council_id = id    
      self.data = the_data if the_data
    end
    
    def name
      @data["name"] || @name
    end
    
    def url
      @data["url"]
    end
    
    def services
      @services ||= Weary.get("http://openlylocal.com/services.json?council_id=#{council_id}").perform.parse.map{|a| Service.new(a["service"], self)} rescue []
    end
    
    def rss_feed_url
      if @data["feed_url"] || @data["url"]
        STDERR.puts "feed url #{@data["feed_url"] }"
        STDERR.puts "guess url #{@data["url"] }"
        @rss_feed_url ||= (@data["feed_url"] || FeedDetector.fetch_feed_url(@data["url"]) )
      end
    end
    
    def rss_feed
      unless rss_feed_url.blank?
        STDERR.puts "RSS Feed url to get #{rss_feed_url}"
        @rss_feed ||= Weary.get(rss_feed_url).perform.parse.first.last["channel"]["item"] 
      end
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
      results = Weary.get("http://boss.yahooapis.com/ysearch/web/v1/site:#{@data["url"]}%20#{terms}?appid=#{YAHOO_BOSS_APP_ID}&count=8&type=html&format=json").perform.parse
      pages = results.first.last["resultset_web"].map{|a| Page.new(a, self)} rescue []
      services.select{|a| a["title"].downcase.include?(terms)} + pages
    end
    
    def info
      @data ||= self.load
    end
    
    def name
      @data["name"]
    end
    
    def load
      @data ||= Weary.get("http://openlylocal.com/councils/#{council_id}.json").perform.parse["council"]
    end
    
    def get_page url
      Page.new({"url"=>url, "title"=>nil}, self)
    end
    
    def performance_url
      return @performance_url unless @performance_url.blank?
      terms = self.name.gsub(" ", "%20")
      results = Weary.get("http://boss.yahooapis.com/ysearch/web/v1/site:http://oneplace.direct.gov.uk%20#{terms}?appid=#{YAHOO_BOSS_APP_ID}&count=1&type=html&format=json").perform.parse
      @performance_url = results.first.last["resultset_web"].first["url"] rescue nil
    end
    
    def performance
      return @performance unless @performance.blank?
      if performance_url
        doc = Nokogiri::HTML.parse(open(performance_url).read)
        @performance = doc.css('div#content div.contentLeft')
      end
    end
    
    def self.all
      @@all_councils ||= Weary.get("http://openlylocal.com/councils/all.json").perform.parse.map{|a| Council.new(a["council"]["id"], a["council"])}
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
    
    def members
      m = Weary.get("http://openlylocal.com/members.json?council_id=#{self.id}").perform.parse.map{|a| a["member"]} rescue m=[]
      STDERR.puts m.inspect
      m
    end
  end
  
  class Member
    attr_accessor :data
    
    def initialize(d)
      @data = d
    end
    
    def [](ind)
      @data[ind]
    end
    
    def self.get id
      m = Member.new(Weary.get("http://openlylocal.com/members/#{id}.json").perform.parse["member"])
      STDERR.puts m.inspect
      m
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
      @extracted ||= Extractomatic.get(self.data["url"])
    end
    
    def readable
      @readable ||= DIY.reroute_links(Readability::Document.new(open(self.data["url"]).read).content)
    end
    
    def title
      @title ||= DIY.titleize(@data["title"], council)
    end
    
    def load_title
      doc = Nokogiri::HTML(open(self.url)) 
      @title = @data["title"] = DIY.titleize(doc.at_css("title").text, self.council)
    end
    
    def url
      @data["url"]
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
    
    def to_json
      "{'title':#{title},'url':#{url}}"
    end
    
    def method_missing(method_name)
      @data[method_name]
    end
  end
end