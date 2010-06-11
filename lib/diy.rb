$: << File.dirname(__FILE__)

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
require 'dm-core'
require 'postgres'
require 'do_postgres'
require 'diy_action'
require 'diy_service'
require 'diy_council_service'
require 'diy_service_action'
require 'phrases'
require 'directgov'
require 'sleepy'
require 'hashie'

YAHOO_BOSS_APP_ID = "7gATyJ7V34FoqrIuRvHAAwMYi_L7gp2ZRFAoTP5sZzQlsNzmC1mjv.2yfvzITyWAhK0INaBA"

module DIY
  
  def self.reload
    load File.expand_path(File.join(File.dirname(__FILE__),"diy.rb"))
  end
  
  def self.connect
    #DataMapper.setup(:default, "postgres://postgres:postgres@localhost:5432/diycouncil_#{ENV["RACK_ENV"] || "development"}")
  end
  
  def self.titleize title, council
    return "" if  title.blank?
    council_name = council["name"]
    separator = nil
    common_separators = [" - ", " • ", " &bull; ", ": ", " | ", ". ", " :: "]
    common_separators.each{|sep| separator = sep if title.include?(sep)}
    if separator
      items = title.split(separator)
      if(items.first.include?(council_name) || items.first.similarity(council_name) > 0.5)
        items.delete_at(0)
      elsif(items.last.include?(council_name) || items.last.similarity(council_name) > 0.5)
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
    STDERR.puts "reroute #{base.class}: #{base}"
    r = rebase_links(base,council)
    STDERR.puts "result: #{r}"
    STDERR.puts "that was the result"
    r.to_s.gsub(/href\=[\"\'](.+)[\"\']/, "href=\"/#{council.slug}/page?url=#{CGI.escape($1)}\"") rescue r
  end
  
  def self.rebase_links(base, council)
    STDERR.puts "rebase #{base.class} : #{base}"
    result = base.gsub(/href\=[\"\'](\/)/){|a| 
    STDERR.puts a
    a.chomp('/') + council["url"].chomp('/') + "/" unless a.blank?}
    result
  end
    
  class Council
    
    attr_accessor :council_id
    attr_accessor :data
    attr_accessor :postcode
    
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
    
    def initialize(id, the_data = nil, p = nil)
      self.council_id = id    
      self.data = the_data if the_data
      self.postcode = p
    end
    
    def name
      @data["name"] || @name
    end
    
    def url
      @data["url"]
    end
    
    def services
      @services ||= Weary.get("http://openlylocal.com/services.json?council_id=#{council_id}").perform_sleepily.parse.map{|a| Service.new(a["service"], self)} rescue []
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
        @rss_feed ||= Weary.get(rss_feed_url).perform_sleepily.parse.first.last["channel"]["item"]  rescue []
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
      @flickr_feed ||= Weary.get("http://www.degraeve.com/flickr-rss/rss.php?tags=#{tag}&tagmode=all&sort=date-posted-desc&num=25").perform_sleepily.parse.first.last["channel"]["item"] rescue nil
    end
    
    def suggest terms
      results = search terms
      STDERR.puts results.inspect
      results.map{|a| {:id=>a.title, :label=>a.title, :value=>a.diy_url}}
    end
    
    def search terms 
      terms = self.class.clean_terms terms
      articles = articles_about(terms) rescue []
      pages = find_pages(terms) rescue []
      articles + services.select{|a| a["title"].downcase.include?(terms)} + pages
    end
    
    def find_pages terms
      results = Weary.get("http://boss.yahooapis.com/ysearch/web/v1/site:#{@data["url"]}%20#{terms}?appid=#{YAHOO_BOSS_APP_ID}&count=8&type=html&format=json").perform_sleepily.parse.first.last["resultset_web"] rescue []
      results.map{|a| Page.new(a, self)} rescue []
    end
    
    def info
      @data ||= self.load
    end
    
    def name
      @data["name"]
    end
    
    def load
      @data ||= Weary.get("http://openlylocal.com/councils/#{council_id}.json").perform_sleepily.parse["council"] rescue []
    end
    
    def get_page url
      Page.new({"url"=>url, "title"=>nil}, self)
    end
    
    def performance_url
      begin
        return @performance_url unless @performance_url.blank?
        terms = self.name.gsub(" ", "%20")
        results = Weary.get("http://boss.yahooapis.com/ysearch/web/v1/site:http://oneplace.direct.gov.uk%20#{terms}?appid=#{YAHOO_BOSS_APP_ID}&count=1&type=html&format=json").perform_sleepily.parse
        @performance_url = results.first.last["resultset_web"].first["url"] rescue nil
      rescue
        nil
      end
    end
    
    def performance
      begin
        return @performance unless @performance.blank?
        if performance_url
          doc = Nokogiri::HTML.parse(Weary.get(performance_url).perform_sleepily.body)
          @performance = DIY.reroute_links(doc.css('div#content div.contentLeft').to_html, self)
        end
      rescue
        nil
      end
    end
    
    def self.all
      @@all_councils ||= Weary.get("http://openlylocal.com/councils/all.json").perform_sleepily.parse.map{|a| Council.new(a["council"]["id"], a["council"])}
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
      begin
        postie = Weary.get("http://openlylocal.com/areas/postcodes/#{postcode.gsub(' ', '')}.json").perform_sleepily.parse["postcode"]
        STDERR.puts postie.inspect
        self.get(postie["council_id"])
      rescue
        nil
      end
    end
    
    def method_missing(method_name)
      @data[method_name]
    end
    
    def id
      @data["id"]
    end
    
    def members
      Weary.get("http://openlylocal.com/members.json?council_id=#{self.id}").perform_sleepily.parse.map{|a| a["member"]} rescue []
    end
    
    def profile_url
      "http://openlylocal.com/councils/#{self.id}"
    end
    
    def stats
      begin
        return @stats unless @stats.blank?
        doc = Nokogiri::HTML.parse(Weary.get(profile_url).perform_sleepily.body)
        @stats = DIY.rebase_links(doc.css('#grouped_datapoints').to_html, {"url"=>"http://openlylocal.com"})
      rescue
        "Sorry - stats are currently unavailable"
      end
    end
    
    def directgov_url
      begin
        return @directgov_url unless @directgov_url.blank?
        terms = self.name.gsub(" ", "%20")
        results = Weary.get("http://boss.yahooapis.com/ysearch/web/v1/site:http://direct.gov.uk%20#{terms}?appid=#{YAHOO_BOSS_APP_ID}&count=1&type=html&format=json").perform.parse
        @directgov_url = results.first.last["resultset_web"].first["url"] rescue nil
      rescue
        nil
      end
    end
    
    def contact_details
      begin
        return @contact_details unless @contact_details.blank?
        return nil if directgov_url.blank?
        doc = Nokogiri::HTML.parse(Weary.get(directgov_url).perform_sleepily.body)
        @contact_details = DIY.add_telephone_microformats(doc.css('.subContent').to_html)
      rescue
        "Sorry - contact details are currently unavailable"
      end
    end
    
    def ons_url
      @data["ons_url"]
    end
    
    def ons_datasets
      begin
        #TODO Looks like ONS has a 'browser check' that only lets you through if you have javascript. Lame.
        return @ons_datasets unless @ons_datasets.blank?
        return nil if ons_url.blank?
        doc = Nokogiri::HTML.parse(Weary.get(ons_url).perform_sleepily.body)
        @ons_datasets = DIY.rebase_links(doc.css('.leftBody').to_html, {"url"=>"http://neighbourhood.statistics.gov.uk/dissemination"})
      rescue
        nil
      end
    end
    
    def woeid_url
      "http://query.yahooapis.com/v1/public/yql?q=select%20woeid%20from%20geo.places%20where%20text%3D%22#{CGI.escape(self.slug.gsub("_"," ") + ", uk")}%22&format=json&diagnostics=true&callback="
    end
    
    def woeid
      return @woeid unless @woeid.blank?
      @woeidres = Weary.get(woeid_url).perform_sleepily.parse["query"]["results"]["place"]["woeid"] rescue nil
    end
    
    def articles_about keyword
      Directgov::Article.find_by_keyword(keyword)
    end
    
    def upcoming_events_url
      "http://query.yahooapis.com/v1/public/yql?q=select%20*%20from%20upcoming.events%20where%20woeid%20in%20(select%20woeid%20from%20geo.places%20where%20text%3D%22#{CGI.escape(self.slug.gsub("_"," ") + ", uk")}%22)%20%7C%20sort(field%3D%22start_date%22)&format=json&diagnostics=true&callback="
    end
    
    def upcoming_events
      return @events unless @events.blank?
      begin
        res = Weary.get(events_url).perform_sleepily.parse["query"]["results"]["event"]
        if res.class == Hash
          @events = [Hashie::Mash.new(res)]
        elsif res.class == Array
          @events = res.map{|a| Hashie::Mash.new(a) }
        end
      rescue
        []
      end
    end
    
    def wcwg_events_url
      "http://www.wcwg.info/feeds/localevents.aspx?a=12345&p=#{postcode.gsub(" ","")}"
    end
    
    def wcwg_events
      return @wcwg_events unless @wcwg_events.blank?
      begin
        res = Weary.get(events_url).perform_sleepily.parse["LocalEvents"]["item"]
        if res.class == Hash
          @wcwg_events = [Hashie::Mash.new(res)]
        elsif res.class == Array
          @wcwg_events = res.map{|a| Hashie::Mash.new(a) }
        end
      rescue
        []
      end
    end
    
    def events
      upcoming_events
    end
    
    def planning_application_surl
      "http://www.planningalerts.com/api.php?postcode=#{@postcode.gsub(" ", "")}&area_size=m"
    end
    
    def planning_applications
      return @planning_applications unless @planning_applications.blank?
      begin
        res = Weary.get(planning_applications_url).perform_sleepily.parse["items"]
        if res.class == Hash
          @planning_applications = [Hashie::Mash.new(res)]
        elsif res.class == Array
          @planning_applications = res.map{|a| Hashie::Mash.new(a) }
        end
      rescue
        []
      end
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
      m = Member.new(Weary.get("http://openlylocal.com/members/#{id}.json").perform_sleepily.parse["member"])
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
      @readable ||= DIY.reroute_links(Readability::Document.new(Weary.get(@data["url"]).perform_sleepily.body).content, self.council)
    end
    
    def title
      return @title unless @title.blank?
      if @data["title"].blank?
        self.load_title
      end
      @title ||= DIY.titleize(@data["title"], council)
    end
    
    def load_title
      doc = Nokogiri::HTML(Weary.get(self.url).perform_sleepily.body)
      STDERR.puts "Got :#{doc.inspect}" 
      STDERR.puts "Title: #{doc.at_css('h1')}"
      
      @title = DIY.titleize(doc.at_css("title").text, self.council) rescue @title = nil
      @title ||= (doc.at_css("h1").text) rescue @title = "Untitled"
      @data["title"] = @title
    end
    
    def url
      @data["url"]
    end
    
    def diy_url
      "/page?url=#{CGI.escape(url)}"
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
      @readable ||= DIY.reroute_links(Readability::Document.new(Weary.get(@data["url"]).perform_sleepily.body).content, self.council)
    end
        
    def title
      @title ||= DIY.titleize(@data["title"], council)
    end
    
    def url
      @data["url"]
    end
    
    def diy_url
      "/page?url=#{CGI.escape(url)}"
    end
    
    def to_json
      "{'title':#{title},'url':#{url}}"
    end
    
    def method_missing(method_name)
      @data[method_name]
    end
  end
end