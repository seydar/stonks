NYSE = Ticker.where(:exchange => 'NYSE').all
Commodities = Ticker.where(:exchange => ['NYBOT',
                                         'CBOT'])
                    .all
Currencies = Ticker.where(:exchange => 'FOREX').all

class Array
  def median
    sort[size / 2]
  end
end

def time
  start  = Time.now
  result = yield
  [Time.now - start, result]
end

# specifically for results hash. takes bars and turns them into hashes
# This prevents the ticker and ALL associated bars from being serialized
# as well
def dehydrate(hash)
  hash[:buy]    = hash[:buy].to_hash
  hash[:sell] &&= hash[:sell].to_hash
  hash
end

def hydrate(hash)
  hash[:buy]    = Bar[hash[:buy][:id]]
  hash[:sell] &&= Bar[hash[:sell][:id]]
  hash
end

def cache(fname, &blk)
  if File.exists? fname
    return Marshal.load(File.read(fname))
  else
    print "writing #{fname}..."
    res = blk.call
    open(fname, "w") {|f| f.write Marshal.dump(res) }
    puts "!"
    res
  end
end

def simulate(**kwargs)
  cache("data/#{folder}_sim/#{year}_d#{drop}_m#{m}_b#{b}.sim") do
    sim = buys(**kwargs)
    sim.run.map {|r| dehydrate r }
  end.map {|r| hydrate r }
end

def holdings(**kwargs)
  res = simulate(**kwargs)
  res.map {|h| h[:buy] }
end

def simulator(holds=nil, **kwargs)
  sim = Simulator.new
  sim.assessor.holding = holds || holdings(**kwargs)
  sim
end

def buys(year: nil,
         drop: nil,
         rank: 60,
         stocks: NYSE,
         m: -0.02,
         b: 5.2,
         folder: "rank")

  # Allow `:year => 2018..2021`
  debut = year.is_a?(Range) ? year.first : year
  fin   = year.is_a?(Range) ? year.last  : year

  sim = Simulator.new :stocks => stocks,
                      :drop   => drop,
                      :rank   => rank,
                      :m      => m,
                      :b      => b,
                      :after  => "1 jan #{debut}",
                      :before => "31 dec #{fin}"
  sim.assess_buys
  sim.holding
end

def profit(results, circulation: 15.0, pieces: 10, reinvest: false, debug: false)
  timeline = results.map do |h|
    o = [{:action => :buy, :stock => h[:buy]}]
    o << {:action   => :sell,
          :stock    => h[:sell],
          :original => h[:buy],
          :ROI      => h[:ROI]} if h[:sell]
    o
  end.flatten(1).sort_by {|r| r[:stock].date }

  skips = []
  investment = Hash.new {|h, k| h[k] = circulation.to_f / pieces }

  history = timeline.inject([circulation]) do |tally, trade|
    if trade[:action] == :sell && skips.include?(trade[:original])
      # nothing
    elsif trade[:action] == :buy && tally.last - investment[trade[:stock]] < 0
      skips << trade[:stock]
    else
  
      if trade[:action] == :buy
        tally << tally.last - investment[trade[:stock]]

        puts "buying #{trade[:stock].ticker.symbol} for " +
             "#{investment[trade[:stock]]}"         if debug

      else # we're selling something we've successfully bought
        puts "selling #{trade[:stock].ticker.symbol} at " +
             "#{(trade[:ROI] * 100).round(3)}% " +
             "($#{investment[trade[:original]].round(3)} => " +
             "$#{(investment[trade[:original]] *
                 (1 + trade[:ROI])).round(3)})"     if debug

        profit = investment[trade[:original]] * trade[:ROI]
        tally << tally.last + investment[trade[:original]] + profit
  
        circulation += profit if reinvest
      end

      puts "\tcash: #{tally.last.round 3}"          if debug
      puts "\tcirculation: #{circulation.round 3}"  if debug
    end
  
    tally
  end

  {:skips   => skips,
   :history => history,
   :ratio   => history[-1].to_f / history[0],
   :circulation => circulation,
   :cash => history[-1]
  }
end

