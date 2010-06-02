class ServiceAction
  include DataMapper::Resource
  
  property :id, Serial
  belongs_to :service
  belongs_to :action
end
