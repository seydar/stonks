class Assessor
  attr_accessor :buying_plan
  attr_accessor :selling_plan
  attr_accessor :history_requirement

  attr_accessor :holding
  attr_accessor :results

  DELISTING_DEADBAND = 7.days

  def buy_when(history: 2, &b)
    @buying_plan = b
    @history_requirement = history
  end

  def sell_when(&b)
    @selling_plan = b
  end

  def buy?(ticker)
    buying_plan[ticker]
  end

  def sell?(ticker, original)
    selling_plan[ticker, original]
  end

  def assess_buys(tickers, opts={})
    tids = tickers.map {|t| t.id }

    debut  = Time.parse(opts[:after].to_s  || '1 march 1900')
    fin    = Time.parse(opts[:before].to_s || Date.today.to_s)

    bars   = Bar.where(:date => debut..fin, :ticker_id => tids)
                .order(:ticker_id, Sequel.asc(:date))
                .all
    groups = bars.group_by {|b| b.ticker_id }

    @holding = []

    # create groups of size `@history_requirement`, and then
    # pass that history to the checker
    # most recent bar is at -1, oldest bar is at 0
    @holding = groups.map do |ticker_id, bars|
      # assume the history is 
      histories = bars.each_cons history_requirement

      histories.filter do |history|

        # verify that the history is consecutive
        day_deltas = history.each_cons(2).map {|a, b| b.date - a.date }

        if day_deltas.any? {|v| v > 4.days }
          false
        else
          buy? history
        end
      end.map {|history| history.last }
    end.flatten

    # `@holding` currently references the days that a decision to buy is made
    # (using the day's closing price), but we don't *actually* buy until the
    # next morning. So we need to replace these stocks with the next day's
    # stock.
    # 
    # This is key because the `Bar#change_from` method operates on the opening
    # price of the earlier day.
    #
    # If `bars[index + 1]` is nil because we're dealing with some HOT OF THE
    # PRESS stock recommendations, then... I don't really have a plan for that
    # yet.  Then the stock doesn't exist, so just present the stock itself.
    # It'll stay until the time period is recalculated, which happens often.
    #
    # From here on out, we're dealing with *simulation*.
    @holding = @holding.map do |stock|
      bars  = Bar.where(:ticker => stock.ticker,
                        :date => stock.date..(stock.date + 7.days))
                 .order(Sequel.asc(:date))
                 .all
      index = bars.index stock
      bars[index + 1] || stock
    end
  end

  def assess_sells(partial: false)
    # assumes `@holding` and `@results` are accurately mapped
    if partial
      verified = @results.filter {|h| h[:sell] }
      unverified_stocks = @results.filter {|h| h[:sell].nil? }
                                  .map    {|h| h[:buy] }
    else
      unverified_stocks, verified = @holding, []
    end

    # Stocks can be delisted, at which point stocks held will be no longer
    # valid, but then a *new* ticker can start and can *reuse* the old name.
    # And since any stocks held from the previous incarnation won't be valid
    # for the new incarnation of the symbol, we need to separate those
    # instances. We do this by looking for a stretch of 7 days (using the date,
    # not the trading days, since trading days is calculated based on the
    # availability of bar information for that specific stock) during which the
    # stock is not traded (stocks can go intermittently inactive for short
    # periods of time, but that doesn't imply delistment).
    stocks_and_bars = unverified_stocks.map do |stock|
      bars     = Bar.where(:ticker => stock.ticker) { date >= stock.date }
                    .order(Sequel.asc(:date))
                    .all
      periods = bars.slice_when do |before, after|
        after.date - before.date >= DELISTING_DEADBAND
      end

      periods.map {|p| [stock, p] }
    end.flatten 1

    unverified = stocks_and_bars.map do |stock, bars|
      sell_bar = bars.find {|day| sell? stock, day }

      {:buy  => stock,
       :sell => sell_bar,
       :hold => sell_bar ? sell_bar.trading_days_from(stock)  : nil,
       :ROI  => sell_bar ? sell_bar.change_from(stock) : -1,
       :delisted => Time.now - bars.last.date >= DELISTING_DEADBAND
      }
    end

    @results = (unverified + verified).sort_by {|h| h[:buy].date }
  end

  def assess(tickers, opts={})
    assess_buys tickers, opts
    assess_sells :partial => opts[:partial]
  end
end

