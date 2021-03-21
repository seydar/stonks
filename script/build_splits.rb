require 'open-uri'
require 'nokogiri'
require './market.rb'

url = proc {|ticker| "http://stocksplithistory.com/?symbol=#{ticker}" }
nyse = Ticker.where(:exchange => 'NYSE').all

# DB.drop_table :splits
# 
# DB.create_table? :splits do
#   primary_key :id
#   foreign_key :ticker_id, :tickers
#   string :ratio
#   datetime :date
# 
#   index :ticker_id
# end

nyse.each do |sym|
  print "\nreviewing #{sym.symbol}: "
  doc = Nokogiri::HTML(URI.open(url[sym.symbol.downcase]))
  possibilities = doc.at 'td:contains("Split History Table")'
  table = possibilities.children[0]
  trs = table.search "tr"
  trs = trs.map {|tr| tr.children.map {|td| td.text } }[1..-1] # strip the headers
  
  trs.each do |tds|
    date = Time.parse(DateTime.strptime(tds[0], "%m/%d/%Y").to_s

    next if Split.where(:ticker_id => sym.id,
                        :ratio     => tds[-1],
                        :ex        => date).count > 0

    Split.create :ticker_id => sym.id,
                 :ratio     => tds[-1],
                 :ex        => date)
    print "."
  end
end

