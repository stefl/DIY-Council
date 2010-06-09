require 'cgi'

module Directgov
  class Article
    attr_accessor :data
    
    def self.find_by_keyword(word)
      Weary.get("http://syndication.innovate.direct.gov.uk/keywords/#{CGI.escape(word)}/articles.json"){|req|
        req.credentials = {:username => ::DIRECTGOV_USER, :password => ::DIRECTGOV_PASS}
      }.perform_sleepily.parse.map{|a| Directgov::Article.new(a["article"])} #rescue []
    end
    
    def initialize(d)
      self.data = d
    end
    
    def self.get(id)
      Directgov::Article.new(Weary.get("http://syndication.innovate.direct.gov.uk/id/article/#{id}.json"){|req|
        req.credentials = {:username => ::DIRECTGOV_USER, :password => ::DIRECTGOV_PASS}
      }.perform_sleepily.parse["article"]) #rescue nil
    end
    
    def [](ind)
      @data[ind]
    end
    
    def readable
      @data["sections"].each.map{|a| a["content"]} unless @data.blank?
    end
    
    def title
      @data["title"]
    end
    
    def url
      "/articles/#{@data["id"]}"
    end
  end
end