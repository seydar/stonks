require 'open-uri'
require 'nokogiri'
require './market.rb'

url = proc {|ticker| "http://stocksplithistory.com/?symbol=#{ticker}" }
nyse = Ticker.where(:exchange => 'NYSE').all

nyse.each do |sym|
  p sym.symbol
  doc = Nokogiri::HTML(URI.open(url[sym.symbol.downcase]))
  possibilities = doc.at 'td:contains("Split History Table")'
  table = possibilities.children[0]
  trs = table.search "tr"
  trs = trs.map {|tr| tr.children.map {|td| td.text } }[1..-1] # strip the headers
  
  trs.each do |tds|
    #puts Time.parse(DateTime.strptime(td[0].strip, "%m/%d/%Y").to_s)
    Split.create :ticker_id => sym.id,
                 :ratio     => tds[-1],
                 :ex        => Time.parse(DateTime.strptime(tds[0], "%m/%d/%Y").to_s)
  end
end

