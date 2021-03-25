class Ticker < Sequel::Model
  one_to_many :bars, :order => :date
  one_to_many :splits, :order => :date

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
  def normalize!
    return @normalized if @normalized
    bars.each {|b| b.id = nil }

    splits.each do |split|
      unnormalized = bars.filter {|b| b.date <= split.date }
      next unless unnormalized.size >= 2
      ratio = unnormalized[-1].open / unnormalized[-2].close
      unnormalized[0..-2].map do |b|
        b.close *= ratio
        b.open  *= ratio
        b.high  *= ratio
        b.low   *= ratio
      end
    end

    @normalized = true
  end

  def normalized?; @normalized; end

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

