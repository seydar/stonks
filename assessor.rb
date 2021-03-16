class Assessor
  attr_accessor :buying_plan
  attr_accessor :selling_plan
  attr_accessor :history_requirement

  attr_accessor :holding

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

    debut = opts[:after] || Time.parse('1 march 1900')
    debut = debut.is_a?(Time) ? debut : Time.parse(debut.to_s)
    fin   = opts[:before] || Time.parse(Date.today.to_s)
    fin   = fin.is_a?(Time) ? fin : Time.parse(fin.to_s)

    bars = Bar.where(:time => debut..fin, :ticker_id => tids)
              .order(:ticker_id, Sequel.asc(:time)).all

    @holding = []

    # create groups of size `@history_requirement`, and then
    # pass that history to the checker
    # most recent bar is at -1, oldest bar is at 0
    bars.map do |ticker_id, bars|
      # assume the history is 
      histories = bars.each_cons history_requirement

      @holding += histories.filter do |history|

        # verify that the history is consecutive
        day_deltas = history.each_cons(2).map {|a, b| b.date - a.date }
        return false if day_deltas.any? {|v| v > 4 }

        buy? history
      end
    end

  end

  def assess_sells
    @holding.map {|stock| sell? stock.ticker, stock }
  end

  def assess(tickers, opts={})
    assess_buys tickers, opts
    assess_sells
  end
end

def sell_point(days_held, drop=120.0)
  [2.0 - days_held / drop, 0].max
end

assessor = Assessor.new
assessor.buy_when :history => 2 do |history|
  today     = history[-1]
  yesterday = history[-2]

  today.change_from(yesterday) <= -0.3 or
    today.change_from(today)   <= -0.3
end

assessor.sell_when do |ticker, original|
  today = ticker.history[-1]
  days_held = today.date - original.date

  today.change_from(original) >= sell_point(days_held)
end

assessor.assess nyse, :after  => '1 jan 2019',
                      :before => '31 dec 2019'

