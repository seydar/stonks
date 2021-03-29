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
  print "\nreviewing #{sym.symbol}: "
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
end

# reflect the splits in the data permanently. or rather... hide the splits in
# the data, permanently
NYSE.each do |ticker|
  p ticker.symbol
  puts "\t#{ticker.splits.size} splits"
  ticker.splits.each do |split|
    next if split.applied

    count_unnormal = DB[:bars].where(:ticker_id => ticker.id,
                                     :date => Time.parse('1 jan 1900')..split[:date])
                              .count

    next unless count_unnormal >= 2

    unnormalized = DB[:bars].where(:ticker_id => ticker.id,
                                   :date => (split[:date] - 30 * 86400)..split[:date])
                            .order(Sequel.asc(:date))
                            .all
    ratio = unnormalized[-1][:open] / unnormalized[-2][:close]

    puts "\tupdating #{count_unnormal} bars"

    DB[:bars].where(:ticker_id => ticker.id,
                    :date => Time.parse('1 jan 1900')..(split[:date] - 1.day))
             .update(:close => Sequel[:close] * ratio,
                     :open  => Sequel[:open]  * ratio,
                     :high  => Sequel[:high]  * ratio,
                     :low   => Sequel[:low]   * ratio)

    split.applied = true
    split.save
  end
end

