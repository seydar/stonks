NYSE = Ticker.where(:exchange => 'NYSE').all

# https://www.purefinancialacademy.com/futures-markets
Futures = {:energy     => ["CL=F", "QM=F", "BZ=F", "EH=F", "HO=F", "NN=F", "NG=F",
                           "QG=F", "RB=F", "UX=F"],
           :metals     => ["HG=F", "QC=F", "GC=F", "YG=F", "ZG=F", "QO=F",
                           "QI=F", "MME=F", "PA=F", "PL=F", "SI=F", "ZI=F", "YI=F"],
           :food_fiber => ["CB=F", "CC=F", "CJ=F", "KC=F", "KT=F", "TT=F", "CT=F",
                           "DY=F", "LB=F", "LBS=F", "DC=F", "GDK=F", "GNF=F",
                           "OJ=F", "YO=F", "SB=F", "SF=F"],
           :grains     => ["C=F", "ZC=F", "XC=F", "YC=F", "O=F", "ZO=F", "RR=F",
                           "ZR=F", "XK=F", "YK=F", "SM=F", "ZM=F", "BO=F",
                           "ZL=F", "S=F", "ZS=F", "W=F", "ZW=F", "XW=F",
                           "YW=F"],
           :indexes    => ["YM=F", "DJ=F", "AW=F", "MFS=F", "ND=F", "NQ=F", "NK=F",
                           "NKD=F", "NIY=F", "SP=F", "ES=F", "GD=F", "GIE=F",
                           "EMD=F", "SU=F"],
           :interests  => ["GLB=F", "TY=F", "ZN=F", "ZT=F", "FV=F", "ZF=F", "ED=F",
                           "GE=F", "FF=F", "ZQ=F", "US=F", "ZB=F", "UB=F"],
           :livestock  => ["FC=F", "GF=F", "HE=F", "LH=F", "LC=F", "LE=F"],
           :currencies => ["6A=F", "ACD=F", "AJY=F", "ANE=F",
                           "6L=F", "6B=F", "PJY=F", "PSF=F", "MP=F", "6C=F",
                           "CJY=F", "RMB=F", "6E=F", "EC=F", "E7=F", "EAD=F",
                           "RP=F", "RY=F", "RF=F", "6J=F", "J7=F", "KRW=F",
                           "6M=F", "MP=F", "6N=F", "NOK=F", "6R=F", "6Z=F",
                           "SEK=F", "6S=F", "SJY=F", "DX=F", "AUDUSD=X",
                           "GBPUSD=X", "USDCAD=X", "EURUSD=X", "USDJPY=X",
                           "NZDUSD=X", "USDCHF=X", "EURAUD=X", "EURGBP=X",
                           "EURCAD=X", "EURDKK=X", "EURJPY=X", "EURNOK=X",
                           "EURSEK=X", "EURCHF=X", "USDHKD=X", "USDINR=X",
                           "USDIDR=X", "USDMYR=X", "EURPHP=X", "USDPHP=X",
                           "USDSGD=X", "USDKRW=X", "USDTHB=X", "USDCZK=X",
                           "USDDKK=X", "USDHUF=X", "USDNOK=X", "USDPLN=X",
                           "USDRUB=X", "USDSEK=X", "USDBRL=X", "USDEGP=X",
                           "USDILS=X", "USDKWD=X", "USDMXN=X", "USDZAR=X",
                           "USDTND=X"],
           :realty     => ["NYM=F"]
          }.map {|k, h| [k, h.map {|sym| Ticker[:symbol => sym] }] }.to_h
Commodities = {:soft => Futures[:food_fiber] + Futures[:grains] + Futures[:livestock],
               :hard => Futures[:energy] + Futures[:metals]
              }

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

def cache(fname, force: false, &blk)
  if File.exists?(fname) && !force
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
  # Have to verify these defaults because the filename is created here
  # but the defaults are otherwise supplied in `#buy`
  kwargs[:folder] ||= "rank"
  kwargs[:m] ||= -0.02
  kwargs[:b] ||= 5.2
  force = kwargs.delete :force

  fname = "data/#{kwargs[:folder]}_sim/" +
          "#{kwargs[:year]}" +
          "_d#{kwargs[:drop]}" +
          "_m#{kwargs[:m]}" +
          "_b#{kwargs[:b]}" +
          ".sim"

  cache(fname, :force => force) do
    sim = buy(**kwargs)
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

def buys(**kwargs)
  buy(**kwargs).holding
end

def buy(year: nil,
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
  sim
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

