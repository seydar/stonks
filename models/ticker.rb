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

