
module Directgov
  class Article
    attr_accessor :data
    
    def self.by_keyword(word)
      Weary.get("http://syndication.innovate.direct.gov.uk/keywords/#{word}/articles.json"){|req|
        req.credentials = {:username => ::DIRECTGOV_USER, :password => ::DIRECTGOV_PASS}
      }.perform.parse.map{|a| Directgov::Article.new(a["article"])} #rescue []
    end
    
    def initialize(d)
      self.data = d
    end
    
    def self.get(id)
      Directgov::Article.new(Weary.get("http://syndication.innovate.direct.gov.uk/id/article/#{id}.json"){|req|
        req.credentials = {:username => ::DIRECTGOV_USER, :password => ::DIRECTGOV_PASS}
      }.perform.parse["article"]) #rescue nil
    end
    
  end
end