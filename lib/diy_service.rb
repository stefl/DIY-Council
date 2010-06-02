class Service
  include DataMapper::Resource
  
  property :id, Integer, :key=>true, :unique=>true
  property :category, String
  property :title, String
  
  has n, :service_actions
  has n, :actions, :through=>:service_actions
end
