class Ticker < Sequel::Model
  one_to_many :bars, :order => :date
  one_to_many :splits, :order => :date

  # Return N_trade / P_day rankings
  #
  # This would be SO MUCH FASTER if I just wrote the SQL by hand (since Sequel
  # doesn't allow me to do GROUP BY and AVG)
  def self.rankings(stocks: nil, date: Time.parse(Date.today.to_s), prior: 10)
    @@rankings ||= {}
    return @@rankings[[stocks, date, prior]] if @@rankings[[stocks, date, prior]]

    tids = stocks.map {|t| t.id }

    query = DB[:bars].where(:ticker_id => tids, :date => (date - prior.days)..date)
                     .group(:ticker_id)
                     .select_append(:ticker_id)
                     .sql
    query.gsub! "*", "AVG(`volume`)"
    volumes = DB.fetch(query).all.inject({}) do |vols, hash|
      vols[hash[:ticker_id]] = hash[:"AVG(`volume`)"]
      vols
    end

    closes = DB[:bars].select(:close, :ticker_id)
                      .where(:ticker_id => tids, :date => date)
                      .all
    closes = closes.inject({}) do |cls, hash|
      cls[hash[:ticker_id]] = hash[:close]
      cls
    end

    # {"SYM" => [Rank, Value]}
    ranks = {}

    values = {}
    stocks.each do |stock|
      if volumes[stock.id] == nil ||
         closes[stock.id] == nil  ||
         closes[stock.id] == 0.0
        values[stock] = 0
      else
        values[stock] = volumes[stock.id] / closes[stock.id]
      end
    end
    sorted_values = values.values.sort.reverse

    values.each {|tick, value| ranks[tick.id] = [sorted_values.index(value), value] }

    @@rankings[[stocks, date, prior]] = ranks
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

  # normalize the prices to get rid of splits
  # percentage drops will still be evident
  #
  # THIS SHOULD BE RARELY CALLED
  # THE DATA SHOULD BE STORED IN ITS NORMALIZED FORM
  def normalize!(debug: false)
    puts "#{symbol}: #{splits.size} splits" if debug

    # operating on hashes and optimized to minimize calls to the DB
    # and also minimizing the number of objects created
    splits.each do |split|
      next if split.applied

      unnorm_size = DB[:bars].where(:ticker_id => id,
                                    :date => Time.parse('1 jan 1900')..split.date)
                             .count

      next unless unnorm_size >= 2

      unnormal = DB[:bars].where(:ticker_id => id,
                                 :date => (split.date - 30 * 86400)..split.date)
                          .order(Sequel.asc(:date))
                          .all
      ratio = unnormal[-1][:open] / unnormal[-2][:close]

      puts "\tupdating #{unnorm_size} bars before #{split.date}" if debug

      DB[:bars].where(:ticker_id => id,
                      :date => Time.parse('1 jan 1900')..(split.date - 1.day))
               .update(:close => Sequel[:close] * ratio,
                       :open  => Sequel[:open]  * ratio,
                       :high  => Sequel[:high]  * ratio,
                       :low   => Sequel[:low]   * ratio)

      split.applied = true
      split.save
    end
  end

  def normalized?; splits.all {|s| s.applied } ; end

  def download_stock(after: '1900-01-01', before: Date.today.strftime("%Y-%m-%d"))
    stock  = AV_CLIENT.stock :symbol => symbol
    series = stock.timeseries :outputsize => 'full'

    bars = series.output['Time Series (Daily)']
    bars = bars.filter {|k, bar| k > after && k < before }

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
    #DB[:bars].multi_insert insertion
  end

  def download_futures(after: '1900-01-01', before: Date.today.strftime("%Y-%m-%d"))
    url = "https://query1.finance.yahoo.com/v7/finance/download/" +
          "#{symbol}?" +
          "period1=#{after.to_i}&" +
          "period2=#{before.to_i}&" +
          "interval=1d&events=history&includeAdjustedClose=true"
    user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 11_2_3) " +
                 "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0.3 " +
                 "Safari/605.1.15"
    data = URI.open(url, "User-Agent" => user_agent) do |site|
      site.read
    end

    data.split("\n").map {|line| line.split "," }.map do |line|
      {:date  => Time.parse(line[0]),
       :open  => line[1].to_f,
       :high  => line[2].to_f,
       :low   => line[3].to_f,
       :close => line[5].to_f,
       :volume => line[6].to_f}
    end
  end

  # hook to ensure no orphans
  def before_destroy
    splits.map {|s| s.destroy }
    bars.map {|b| b.destroy }
    super
  end
end

