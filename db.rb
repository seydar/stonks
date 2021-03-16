require 'sqlite3'
require 'sequel'
require 'alpaca/trade/api'
require 'ruby_linear_regression'
require 'linefit'

DB = Sequel.connect "sqlite://tickers.db"

DB.create_table? :bars do
  primary_key :id
  foreign_key :ticker_id, :tickers
  index :ticker_id
  float :close
  float :high
  float :low
  float :open
  datetime :time
  integer :volume
  string :span # day, 15 min, 5 min, 1 min
end

DB.create_table? :tickers do
  primary_key :id
  string :symbol
  string :exchange
end

DB.create_table? :splits do
  primary_key :id
  foreign_key :ticker_id, :tickers
  index :ticker_id

  string :ratio
  datetime :announcement
  datetime :record
  datetime :ex
end

require './models/ticker.rb'
require './models/split.rb'
require './models/bar.rb'

class Alpaca::Trade::Api::Bar
  def save(symbol, period)
    ::Bar.create :symbol => symbol,
                 :span   => period,
                 :close  => @close,
                 :high   => @high,
                 :low    => @low,
                 :open   => @open,
                 :time   => @time,
                 :volume => @volume,
                 :ticker_id => ::Ticker.where(:symbol => symbol).first.id
  end
end

