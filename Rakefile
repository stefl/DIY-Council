$: << "lib"
require "diy"

DataMapper.setup(:default, "postgres://postgres:postgres@localhost:5432/diycouncil_development")

DataMapper.auto_migrate!

namespace :db do
  desc "load service data from csv"
  task :load_service_data do
    require 'fastercsv'
    Service.all.destroy!
    FasterCSV.foreach("data/links.csv") do |row|
      #In this format: Category (LGNL 2nd level),LGSL,LGIL,ServiceName,Authority level,Url
      cat = row[0]
      lgsl = row[1].to_i
      lgil = row[2].to_i
      name = row[3]
      level = row[4]
      url = row[5]
      Service.create(:category=>cat, :name=>name, :lgsl =>lgsl, :lgil=>lgil, :authority_level=>level, :url=>url)
    end    
    STDERR.puts Service.all.inspect
  end  
end