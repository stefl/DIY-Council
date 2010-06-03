# An action is something that someone might search for to access a service
# Eg. Typing in "recycling" should give you a list of "services" that the local authority will provide you for recycling things
class Action
  include DataMapper::Resource
  
  property :id, Serial, :key=>true
  property :word, String
  
  has n, :service_actions
  has n, :services, :through=>:service_actions
  
end
