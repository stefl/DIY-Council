require 'memcached'
  
module Weary
  
  class Request
    
    def self.sleepy
      @@sleepy ||= Memcached.new
    end
    
    def sleepy
      self.class.sleepy
    end
    
    def round_time(integer, factor)
      return integer if(integer % factor == 0)
      return integer - (integer % factor)
    end
    
    def perform_sleepily(timeout=60*60*1000, &block)
      @on_complete = block if block_given?
      response = perform_sleepily!(timeout)
      response.value
    end
    
    # Redefine the perform method
    def perform_sleepily!(timeout=60*60*1000, &block)
      @on_complete = block if block_given?
      Thread.new {
        STDERR.puts "Before send: #{uri}"
        before_send.call(self) if before_send
        
        STDERR.puts "try nap"
        nap = sleepy.get("#{round_time(Time.new.to_i, timeout)}:#{uri}") rescue nil
        
        unless nap.blank?
          STDERR.puts "Return cached result #{nap.inspect}"
          nap
        else
          req = http.request(request)
          
          response = Response.new(req, self)
          begin
            if response.redirected? && follows?
              response.follow_redirect
            else
              on_complete.call(response) if on_complete
              response
            end
            sleepy.set("#{round_time(Time.new.to_i, timeout)}:#{uri}", response)
            sleepy.set("0:#{uri}", response)
          rescue
            sleepy.get("0:#{uri}") rescue nil
          end
          response
        end
      }
    end
  end
end