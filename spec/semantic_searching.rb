require 'spec_helper.rb'

describe "semantic searching - text as interface!" do
  
  before do
    Service.all.destroy!
    Action.all.destroy!
    @council_tax = Service.create(:id=>1, :title=>"Find out how to pay your Council Tax online", :category=>"Taxation")
    @action = Action.create(:word=>"council tax")
    @action.services << @council_tax
    @action.save
    @action.services.size.should eql(1)
  end
  
  it "should be possible to find the council tax service from the action" do
    action = Action.first(:word=>"council tax")
    action.should eql(@action)
    action.services.size.should eql(1)
    action.services.first.should eql(@council_tax)
  end
  
  it "should recommend a service based on a keyword" do
    
  end
  
  it "should give me a page on my council's website for a keyword" do
    brum = Council.from_slug("birmingham")
    brum.url.should eql("http://birmingham.gov.uk")
    brum.page_about("council tax").should eql("http://www.birmingham.gov.uk/counciltax")
  end
  
  it "should take me to the council tax page" do
    pending
  end
  
end