class Ticker < Sequel::Model
  one_to_many :bars, :order => :date
  one_to_many :splits, :order => :date

  # Return N_trade / P_day rankings
  # Unsure if I want to memoize this to some extent
  def self.rankings(stocks: nil, date: Time.parse(Date.today.to_s), prior: 10)
    tids = stocks.map {|t| t.id }
    bars = Bar.where(:ticker_id => tids, :date => (date - prior.days)..date).all

    rev_map = stocks.inject({}) {|h, t| h[t.id] = t.symbol; h }
    groups  = bars.group_by {|b| b.ticker_id }

    # {"SYM" => Rank}
    ranks = {}
    groups.map do |tid, bz|
      n_trade = bz.map {|b| b.volume }.mean
      p_day   = bz.sort_by {|b| b.date }[-1].close
      ranks[rev_map[tid]] = n_trade / p_day
    end
    ranks
  end

  # bar history based on a bar
  def history(around: nil, prior: 10, post: 5)
    idx  = around ? bars.index(around) : -1
    bars[[idx - prior + 1, 0].max..(idx + post)]
  end

  def volumes(at: nil, prior: 10, post: 0)
    history(:around => at, :prior => prior, :post => post).map {|b| b.volume }
  end

  # This is an absolute value, so a line with 3% shift of a trend at $600 will
  # have a greater MSE than a line with 3% shift of a trend at $6.
  # The cheaper a stock is, the more volatility it is allowed to have.
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

  # Find all 2-day drops of at least `drop`
  def drops(drop)
    # oldest bar is first
    bars.each_cons(2).filter do |span|
      span[-1].change_from(span[0]) <= drop
    end
  end

  # Find all 2-day rises of at least `rise`
  def rises(rise)
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
      split.date <= sell.date and split.date >= bar.date
    end
  end

  # normalize the prices to get rid of splits
  # percentage drops will still be evident
  #
  # THIS SHOULD BE RARELY CALLED
  # THE DATA SHOULD BE STORED IN ITS NORMALIZED FORM
  def normalize!(debug: false)
    # operating on hashes and optimized to minimize calls to the DB
    # and also minimizing the number of objects created
    ticker.splits.each do |split|
      next if split.applied

      unnorm_size = DB[:bars].where(:ticker_id => id,
                                    :date => Time.parse('1 jan 1900')..split[:date])
                             .count

      next unless unnorm_size >= 2

      unnormal = DB[:bars].where(:ticker_id => id,
                                 :date => (split[:date] - 30 * 86400)..split[:date])
                          .order(Sequel.asc(:date))
                          .all
      ratio = unnormal[-1][:open] / unnormal[-2][:close]

      puts "\tupdating #{unnorm_size} bars" if debug

      DB[:bars].where(:ticker_id => id,
                      :date => Time.parse('1 jan 1900')..(split[:date] - 1.day))
               .update(:close => Sequel[:close] * ratio,
                       :open  => Sequel[:open]  * ratio,
                       :high  => Sequel[:high]  * ratio,
                       :low   => Sequel[:low]   * ratio)

      split.applied = true
      split.save
    end
  end

  def normalized?; splits.all {|s| s.applied } ; end

  def before_destroy
    splits.map {|s| s.destroy }
    bars.map {|b| b.destroy }
    super
  end

  def download!(since: '2008-01-01')
    stock  = AV_CLIENT.stock :symbol => symbol
    series = stock.timeseries :outputsize => 'full'

    bars = series.output['Time Series (Daily)']
    bars = bars.filter {|k, bar| k > since }

    insertion = bars.map do |k, bar|
      {:date   => Time.parse(k),
       :open   => bar['1. open'].to_f,
       :high   => bar['2. high'].to_f,
       :low    => bar['3. low'].to_f,
       :close  => bar['4. close'].to_f,
       :volume => bar['5. volume'].to_i,
       :span   => 'day',
       :ticker_id => id
      }
    end
    DB[:bars].multi_insert insertion
  end
end

