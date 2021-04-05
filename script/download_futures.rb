require './market.rb'
require './script/helpers.rb'
require 'open-uri'
require 'pry'
require 'pp'

START  = Time.parse("1 jan 2008")
FINISH = Time.now

def url(stock, after: START, before: FINISH)
  "https://query1.finance.yahoo.com/v7/finance/download/" +
    "#{stock}?" +
    "period1=#{after.to_i}&" +
    "period2=#{before.to_i}&" +
    "interval=1d&events=history&includeAdjustedClose=true"
end
user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 11_2_3) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0.3 Safari/605.1.15"

# "Name \t Symbol \t Exchange"
futures = File.read('data/futures.txt').split("\n").map do |line|
  line.split "\t"
end

fails = []
futures.each do |future|
  puts future[1]
  ending = future[2] == "FOREX" ? "=X" : "=F"

  next if Ticker[:symbol => future[1] + ending]

  begin
    open("data/futures/#{future[1] + ending}.txt", "w") do |f|
      URI.open(url(future[1] + ending), "User-Agent" => user_agent) do |site|
        f.write site.read
        puts "\tdownloaded data"
      end
    end
  rescue
    puts "\tfail"
    fails << future
    next
  end

  Ticker.create :symbol => future[1] + ending, :exchange => future[2]
  puts "\tcreated new ticker"
end

puts "Fails:"
pp fails

binding.pry

