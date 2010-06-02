class CouncilService
  include DataMapper::Resource
  
  property :id, Serial
  property :council_id, Integer
  
  belongs_to :service
end
