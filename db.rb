require 'sqlite3'
require 'sequel'
require 'alpaca/trade/api'

DB = Sequel.connect "sqlite://data/tickers.db.bak"

DB.create_table? :bars do
  primary_key :id
  foreign_key :ticker_id, :tickers
  float :close
  float :high
  float :low
  float :open
  datetime :datetime
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

require './models/ticker.rb'
require './models/split.rb'
require './models/bar.rb'

class Alpaca::Trade::Api::Bar
  def date; @time; end

  def save(symbol, period)
    ::Bar.create :span   => period,
                 :close  => @close,
                 :high   => @high,
                 :low    => @low,
                 :open   => @open,
                 :date   => @time,
                 :volume => @volume,
                 :ticker_id => ::Ticker.where(:symbol => symbol).first.id
  end
end

class Numeric
  # useful for dealing with Time
  def days
    self * 86400.0
  end
  alias_method :day, :days
end

