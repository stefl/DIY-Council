require 'spec_helper.rb'

describe "telephone numbers" do
  it "should create a microformat for a uk number with no spaces" do
    tel = "01212122233"
    DIY.add_telephone_microformats(tel).should eql("<span class='telephone'>01212122233</span>")
  end
  
  it "should handle spaces" do
    tel = "0121 212 2233"
    DIY.add_telephone_microformats(tel).should eql("<span class='telephone'>01212122233</span>")
  end
  
  it "should handle longer numbers" do
    tel = "0207 2122 2334"
    DIY.add_telephone_microformats(tel).should eql("<span class='telephone'>020721222334</span>")
  end
  
  it "should handle (+44)0 notation" do
    tel = "(+44)01212122233"
    DIY.add_telephone_microformats(tel).should eql("<span class='telephone'>01212122233</span>")
  end
  
  it "should handle (+44) notation" do
    tel = "(+44)1212122233"
    DIY.add_telephone_microformats(tel).should eql("<span class='telephone'>01212122233</span>")
  end
  
  it "should handle +44(0) notation" do
    tel = "+44(0)1212122233"
    DIY.add_telephone_microformats(tel).should eql("<span class='telephone'>01212122233</span>")
  end
  
  it "should handle +44 notation" do
    tel = "+441212122233"
    DIY.add_telephone_microformats(tel).should eql("<span class='telephone'>01212122233</span>")
  end
end