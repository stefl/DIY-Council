class Action
  include DataMapper::Resource
  
  property :id, Serial, :key=>true
  property :word, String
  
  has n, :service_actions
  has n, :services, :through=>:service_actions
  
end
