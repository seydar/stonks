require 'sqlite3'
require 'sequel'
require 'alpaca/trade/api'
require 'ruby_linear_regression'
require 'linefit'

DB = Sequel.connect "sqlite://tickers.db"

# I acknowledge that this should be using a foreign key for the symbol
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

class Ticker < Sequel::Model
  one_to_many :bars, :order => :time
  one_to_many :splits, :order => :ex

  # bar history based on a bar
  def history(around: nil, prior: 10, post: 5)
    idx  = around ? bars.index(around) : -1
    bars[[idx - prior + 1, 0].max..(idx + post)]
  end

  def volume(at: nil, prior: 10, post: 0)
    history(:around => at, :prior => prior, :post => post).map {|b| b.volume }
  end

  # just looks at the standard deviation of the open and close prices
  #
  # :at => starting point
  # :prior => how many days prior
  def volatility_stddev(at: nil, prior: 10)
    domain = history(:around => at, :prior => prior)[0..-2]
    prices = domain.map {|b| [b.open, b.close] }.flatten
    prices.standard_deviation / prices.mean
  end

  # MSE is abritrary. Find a way to normalize it against stock price
  # Maybe divide it by the standard deviation? or the mean price?
  def mse(at: nil, prior: 10)
    regression(:at => at, :prior => prior).meanSqError
  end

  # r^2 = 1 - NMSE
  #
  # Since I was originally using MSE and then I wanted to normalize it,
  # r^2 became an easier figure to use. Still gotta write my own function
  # for it (and particularly NMSE) so I can claim I understand it.
  def rsquared(at: nil, prior: 10)
    regression(:at => at, :prior => prior).rSquared
  end

  def regression(at: nil, prior: 10)
    domain   = history(:around => at, :prior => prior, :post => 0)[0..-2]
    prices   = domain.map {|b| [b.open, b.close] }.flatten
    xs       = (1..prices.size).to_a

    line_fit = LineFit.new
    line_fit.setData xs, prices 
    line_fit
  end

  def volatility(at: nil, prior: 10)
    rsquared :at => at, :prior => prior
  end

  def drop(drop)
    # oldest bar is first
    bars.each_cons(2).filter do |span|
      span[-1].change_from(span[0]) <= drop
    end
  end

  def rise(rise)
    # oldest bar is first
    bars.each_cons(2).filter do |span|
      span[-1].change_from(span[0]) >= rise
    end
  end

  # measure trading days, not calendar days, because
  # we need to be consistent. the only way to look at trading
  # days is to look at what we have the data for (otherwise we
  # need some *serious* calendar skillz)
  def split_after?(bar, days: 64)
    sell = bars[bars.index(bar) + days] || bars.last
    splits.any? do |split|
      split.ex <= sell.time and split.ex >= bar.time
    end
  end

  # normalize the prices to get rid of splits
  # percentage drops will still be evident
  def normalize!
    return @normalized if @normalized
    bars.each {|b| b.id = nil }

    splits.each do |split|
      unnormalized = bars.filter {|b| b.time <= split.ex }
      next unless unnormalized.size >= 2
      ratio = unnormalized[-1].open / unnormalized[-2].close
      unnormalized[0..-2].map do |b|
        b.close *= ratio
        b.open  *= ratio
      end
    end

    @normalized = true
  end

  def normalized?; @normalized; end
end

class Bar < Sequel::Model
  many_to_one :ticker

  def self.download(tickers, opts={})
    span = opts.delete(:span) || 'day'

    opts.each do |k, v| 
      if [String, Date, DateTime, Time].include? v.class
        opts[k] = DateTime.parse(v.to_s).to_s
      end
    end

    # `CLIENT.bars` returns a hash, so this will also merge them all
    # into one. key collision will only happen if the key is duplicated
    # in the `ticker` argument.
    symbols = tickers.map {|t| t.symbol }
    symbols.each_slice(50).map do |ticks|
      CLIENT.bars span, ticks, opts
    end.inject({}) {|h, v| h.merge v }
  end

  def inspect
    "#<Bar id => #{id}, sym => #{ticker.symbol}, time => #{time.strftime "%Y-%m-%d"}, o => #{open}, c => #{close}, h => #{high}, l => #{low}>"
  end

  def refresh
    ticker.bars.filter {|b| b.time == time }[0]
  end

  # the "rise" part of the name is baked into the `>=`
  def time_to_rise(percent)
    # most recent is first
    bars  = self.ticker.bars
    index = bars.index self
    #i = bars[index..-1].index

    (index..bars.size - 1).each do |j|
      if bars[j].change_from(bars[index]) >= percent
        #if self.before_split?(:days => j - index)
        #  return -2
        #else
          return j - index
        #end
      end
    end

    -1
  end

  def time_to_rise_norm(percent)
    wait_time = time_to_rise percent

    if before_split? :days => wait_time
      index = ticker.bars.index self
      ticker.bars
      ticker.normalize!
      rec = ticker.bars[index] # the object won't be the same
      wait_time = rec.time_to_rise percent
    end

    wait_time
  end

  def max_rise_over(days)
    index = ticker.bars.index self
    range = ticker.bars[(index + 1)..(index + days)]
    range.map {|b| [b, b.change_from(self)] }.max {|a, b| a[1] <=> b[1] }
  end

  def change_from(bar)
    (close - bar.open).to_f / bar.open
  end

  def rsquared(prior: 10)
    ticker.rsquared(:at => self, :prior => prior)
  end

  def mse(prior: 10)
    ticker.mse(:at => self, :prior => prior)
  end

  def history(prior: 10, post: 0)
    ticker.history(:around => self, :prior => prior, :post => post)
  end

  def volumes(prior: 10)
    history(:prior => prior).map {|b| b.volume }
  end

  def regression(prior: 10)
    ticker.regression(:at => self, :prior => prior)
  end

  def drop(drop)
    i    = ticker.bars.index self
    fin  = ticker.bars.size - 1
    bars = ticker.bars[i..fin]

    # oldest bar is first
    bars.each_cons(2).filter do |span|
      span[-1].change_from(span[0]) <= drop
    end
  end

  def rise(rise)
    i    = ticker.bars.index self
    fin  = ticker.bars.size - 1
    bars = ticker.bars[i..fin]

    # oldest bar is first
    bars.each_cons(2).filter do |span|
      span[-1].change_from(span[0]) >= rise
    end
  end

  def before_split?(days: 90)
    ticker.split_after? self, :days => days
  end
end

class Split < Sequel::Model
  many_to_one :ticker
end

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

class Alpaca::Trade::Api::Client
  def bars(timeframe, symbols, opts={})
    opts[:limit] ||= 100
    opts[:symbols] = symbols.join(',')

    validate_timeframe(timeframe)
    response = get_request(data_endpoint, "v1/bars/#{timeframe}", opts)
    json = JSON.parse(response.body)
    json.keys.each_with_object({}) do |symbol, hash|
      hash[symbol] = json[symbol].map { |bar| Alpaca::Trade::Api::Bar.new(bar) }
    end
  end 
end

