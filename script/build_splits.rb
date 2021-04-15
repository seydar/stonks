require 'open-uri'
require 'nokogiri'
require './market.rb'
require './script/helpers.rb'

url = proc {|ticker| "http://stocksplithistory.com/?symbol=#{ticker}" }

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

NYSE.each do |sym|
  print "reviewing #{sym.symbol}: "
  doc = Nokogiri::HTML(URI.open(url[sym.symbol.downcase]))
  possibilities = doc.at 'td:contains("Split History Table")'
  table = possibilities.children[0]
  trs = table.search "tr"
  trs = trs.map {|tr| tr.children.map {|td| td.text } }[1..-1] # strip the headers
  
  trs.each do |tds|
    date = Time.parse(DateTime.strptime(tds[0], "%m/%d/%Y").to_s)

    next if Split.where(:ticker_id => sym.id,
                        :ratio     => tds[-1],
                        :date      => date).count > 0

    Split.create :ticker_id => sym.id,
                 :ratio     => tds[-1],
                 :date      => date
    print "."
  end
  puts
end

# reflect the splits in the data permanently. or rather... hide the splits in
# the data, permanently
NYSE.each do |ticker|
  p ticker.symbol
  puts "\t#{ticker.splits.size} splits"

  ticker.normalize! :debug => true
end

