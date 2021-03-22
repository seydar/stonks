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

  def max_rise_over(days)
    index = ticker.bars.index self
    range = ticker.bars[index..(index + days)]
    range.map {|b| [b, b.change_from(self)] }.max_by {|a| a[1] }
  end

  def change_from(bar)
    (close - bar.open).to_f / bar.open
  end

  def trading_days_from(from)
    raise unless from.ticker == ticker

    bars = ticker.bars
    (bars.index(self) - bars.index(from)).abs # this may bite me
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

  def date
    time.to_datetime
  end

  def date=(val)
    self.time = Time.parse(val.to_s)
  end
end

