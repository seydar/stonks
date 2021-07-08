class Bar < Sequel::Model
  many_to_one :ticker

  def next(num=1)
    bars = Bar.where(:date   => date..(date + (10 + num * 1.4).days.ceil),
                     :ticker => ticker)
              .order(Sequel.asc(:date))
              .limit(num + 1)
              .all
    num == 1 ? bars[1] : bars[1..num] # `bars[0]` is `self`
  end

  def prev(num=1)
    bars = Bar.where(:date   => (date - (10 + num * 1.4).days.ceil)..date,
                     :ticker => ticker)
              .order(Sequel.asc(:date))
              .limit(num + 1)
              .all
    num == 1 ? bars[-2] : bars[-(num + 1)..-2] # `bars[-1]` is `self`
  end

  def inspect
    "#<Bar id => #{id}, sym => #{ticker.symbol}, date => #{date.strftime "%Y-%m-%d"}, o => #{open}, c => #{close}, v => #{volume}, r => #{rank}>"
  end

  # NYSE delists you if you close at < $1.00 for 30 consecutive days
  # NASDAQ is $1.47
  def days_under_trading_min(min=1.0)
    history = prev 30
    history.slice_when {|b, a| b.close >= min || a.close >= min }
           .filter {|bs| bs.all? {|b| b.close < min } }
           .last
           .size
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
       .count - 1
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

  def changes_over(days)
    bars  = self.next days
    index = bars.index self
    range = bars[index..(index + days)]
    range.map {|b| [b, b.change_from(self)] }
  end

  # What is the maximum percent rise when compared to `self` over the next
  # `days` trading days?
  def max_rise_over(days)
    changes_over(days).max_by {|a| a[1] }
  end

  # What is the maximum percent rise when compared to `self` over the next
  # `days` trading days?
  def max_drop_over(days)
    changes_over(days).min_by {|a| a[1] }
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

  #########################################

  def self.build_rankings(stocks: [],
                          start:  Date.today,
                          finish: Date.today,
                          debug:  false)
    trie = Hash.new {|h, k| h[k] = {} }
    
    puts "#{finish - start + 1} day#{finish - start == 0 ? "" : "s"}" if debug
    start.upto finish do |date|
      puts date if debug
      date = Time.parse date.to_s
    
      # {Ticker ID => [Rank, Value]}
      rankings = Ticker.rankings :stocks => NYSE, :date => date
      rankings.each do |tid, (rank, value)|
        trie[tid][date] = {:rank => rank, :value => value}
      end
    end
    
    bars = DB[:bars].select(:id, :ticker_id, :date)
                    .where(:date => Time.parse(start.to_s)..Time.parse(finish.to_s))
                    .all
    
    num = 0
    DB.synchronize do |conn|
      Upsert.batch(conn, :bars) do |upsert|
        bars.each do |bar|
          rank = trie[bar[:ticker_id]][bar[:date]]
          next unless rank
          upsert.row({:id => bar[:id]}, :rank       => rank[:rank],
                                        :rank_value => rank[:value])
          num += 1
        end
      end
    end
    
    puts "updated #{num} rows across #{finish - start} days" if debug
    num
  end
end

