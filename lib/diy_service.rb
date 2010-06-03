# A service is something that a local authority should provide to visitors of its website
class Service
  include DataMapper::Resource
  
  property :id, Serial, :key=>true
  property :category, String
  property :name, String, :length=>255
  property :lgil, Integer
  property :lgsl, Integer
  property :authority_level, String
  property :url, String, :length=>255

  has n, :service_actions
  has n, :actions, :through=>:service_actions
  
  def self.all_words
    words = []
    Service.all.map{|a| a.name.split(' ').each{|b| words << b.downcase} }
    words
  end
  
  def self.distinct_words
    self.all_words.uniq
  end
end
