require 'sqlite3'
require 'sequel'
require 'alpaca/trade/api'
require 'linefit'
require 'upsert'

ENV['UPSERT_DEBUG'] = "false"

DB = Sequel.connect "sqlite://#{CONFIG[:DB][:path]}"

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
  integer :rank
  float :value

  index :ticker_id
end

DB.create_table? :tickers do
  primary_key :id
  string :symbol
  string :exchange
  boolean :active
end

DB.create_table? :splits do
  primary_key :id
  foreign_key :ticker_id, :tickers
  string :ratio
  datetime :date

  index :ticker_id
end

DB.create_table? :accounts do
  primary_key :id
  string :name
  string :alpaca_id
  string :alpaca_secret
  float :circulation
  float :pieces
end

DB.create_table? :orders do
  primary_key :id
  foreign_key :account_id, :accounts
  foreign_key :bought_id, :bars
  foreign_key :sold_id, :bars
  integer :quantity
  datetime :date
  boolean :complete
end

require_relative 'models/ticker.rb'
require_relative 'models/split.rb'
require_relative 'models/bar.rb'
require_relative 'models/account.rb'

class Alpaca::Trade::Api::Bar
  def date; @time; end

  def save(symbol, period)
    if symbol.is_a? ::Ticker
      tid = symbol.id
    else
      tid = ::Ticker.where(:symbol => symbol).first.id
    end

    ::Bar.create :span   => period,
                 :close  => @close,
                 :high   => @high,
                 :low    => @low,
                 :open   => @open,
                 :date   => @time,
                 :volume => @volume,
                 :ticker_id => tid
  end
end

class Numeric
  def seconds
    self
  end
  alias_method :second, :seconds
  alias_method :sec, :seconds

  def minutes
    self * 60
  end
  alias_method :minute, :minutes
  alias_method :min, :minutes

  def hours
    self * 60.minutes
  end
  alias_method :hour, :hours

  # useful for dealing with Time
  def days
    self * 24.hours
  end
  alias_method :day, :days
end

