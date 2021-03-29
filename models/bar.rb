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
      ALP_CLIENT.bars span, ticks, opts
    end.inject({}) {|h, v| h.merge v }
  end

  def inspect
    "#<Bar id => #{id}, sym => #{ticker.symbol}, date => #{date.strftime "%Y-%m-%d"}, o => #{open}, c => #{close}, h => #{high}, l => #{low}>"
  end

  # GREAT trick here: the goal is to figure out how many records
  # exist between `self` and `from`. Since a simple date calculation
  # won't work, we just ask the DB to see what's in store for us.
  #
  # This originally loaded up `ticker.bars` and then got the indices
  # for the two elements, but then that got turned into querying the DB
  # directly and operating on that list, but then I realized it was the
  # size of that array minus 1, and then I realized I could just get the
  # count directly from the DB.
  def trading_days_from(from)
    raise unless from.ticker == ticker

    dates = [date, from.date].sort

    Bar.where(:ticker => ticker, :date => dates[0]..dates[-1])
       .order(Sequel.asc(:date))
       .count - 1
  end

  def before_split?(days: 90)
    ticker.split_after? self, :days => days
  end

  def refresh
    ticker.bars.filter {|b| b.date == date }[0]
  end

  # the "rise" part of the name is baked into the `>=`
  # How many trading days does it take to rise by `percent`?
  # Returns -1 if it never does.
  def time_to_rise(percent)
    #bars  = self.ticker.bars
    bars  = Bar.where(:ticker => ticker) { date >= self.date }
               .order(Sequel.asc(:date))
               .all
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

  # What is the maximum percent rise when compared to `self` over the next
  # `days` trading days?
  def max_rise_over(days)
    # these will be unnormalized
    # ugh i should really just make the normalization permanent
    #bars  = Bar.where(:ticker => ticker,
    #                  :date => date..(date + (days * 1.4).ceil * 86_400))
    #           .order(Sequel.asc(:date))
    #           .all
    bars  = ticker.bars
    index = bars.index self
    range = bars[index..(index + days)]
    range.map {|b| [b, b.change_from(self)] }.max_by {|a| a[1] }
  end

  # When is the first two-day period that drops by `drop`, after this bar?
  def drop(drop)
    bars  = Bar.where(:ticker => ticker) { date >= self.date }
               .order(Sequel.asc(:date))
               .all
    i    = bars.index self
    fin  = bars.size - 1
    bars = bars[i..fin]

    # oldest bar is first
    bars.each_cons(2).find do |span|
      span[-1].change_from(span[0]) <= drop
    end
  end

  # When is the first two-day period that rises by `rise`, after this bar?
  def rise(rise)
    bars  = Bar.where(:ticker => ticker) { date >= self.date }
               .order(Sequel.asc(:date))
               .all
    i    = bars.index self
    fin  = bars.size - 1
    bars = bars[i..fin]

    # oldest bar is first
    bars.each_cons(2).find do |span|
      span[-1].change_from(span[0]) >= rise
    end
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
end

