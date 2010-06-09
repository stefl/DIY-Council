# Extracts text using the Extractomatic web service:
# http://extractomatic.tomtaylor.co.uk/


class Extractomatic
  
  def self.get url, mode="default"
    result = Weary.get("http://extractomatic.tomtaylor.co.uk/extract?mode=#{mode}&url=#{url}").perform_sleepily.parse
    if result["status"] == "success"
      result["response"]
    end
  end
end

