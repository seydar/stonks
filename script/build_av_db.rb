require 'alphavantagerb'
require 'sqlite3'
require 'sequel'
require 'pry'

DB = Sequel.connect "sqlite://av.db"

DB.create_table? :bars do
  primary_key :id
  foreign_key :ticker_id, :tickers
  float :close
  float :high
  float :low
  float :open
  datetime :date
  integer :volume
  string :span # day, 15 min, 5 min, 1 min

  index :ticker_id
end

DB.create_table? :tickers do
  primary_key :id
  string :symbol
  string :exchange
end

DB.create_table? :splits do
  primary_key :id
  foreign_key :ticker_id, :tickers
  string :ratio
  datetime :date

  index :ticker_id
end

#old = Sequel.connect "sqlite://tickers.db"
#tickers = old[:tickers].all
#tickers.each {|t| t.delete :id }
#DB[:tickers].multi_insert tickers
#__END__

tickers = DB[:tickers].where(:exchange => 'NYSE').all.filter do |t|
  !t[:symbol].include?("-") && !t[:symbol].include?(".")
end
#tickers = DB[:tickers].where(:symbol => 'SPY').all
puts "#{tickers.size} tickers"
client  = Alphavantage::Client.new :key => "GI387ZJ0874WXW5S"

# Query the data for the past 10 years for each ticker
tickers.each do |ticker|
  next if DB[:bars].where(:ticker_id => ticker[:id]).count > 0

  thread = Thread.new { sleep 12.5 } # 5 req/min
  print ticker[:symbol]

  begin
    stock  = client.stock :symbol => ticker[:symbol]
    series = stock.timeseries :outputsize => 'full'
  rescue => e
    # if we're reached our limit, head for the hills
    if e.to_s =~ /500 calls per day/
      puts "\t!!!\t=> 500-call limit reached"
      break
    end

    puts "\t!!!"
    thread.join
    next
  end

  bars   = series.output['Time Series (Daily)']
  bars   = bars.filter {|k, bar| k > '2008-01-01' }
  insertion = bars.map do |k, bar|
    {:date   => Time.parse(k),
     :open   => bar['1. open'].to_f,
     :high   => bar['2. high'].to_f,
     :low    => bar['3. low'].to_f,
     :close  => bar['4. close'].to_f,
     :volume => bar['5. volume'].to_i,
     :span   => 'day',
     :ticker_id => ticker[:id]
    }
  end
  DB[:bars].multi_insert insertion
  puts "..."

  thread.join
end

binding.pry

