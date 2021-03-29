NYSE = Ticker.where(:exchange => 'NYSE').all

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

def simulate(year: nil, drop: nil, stocks: NYSE, m: -0.02, b: 5.2)
  cache("data/sim/#{year}_#{drop.abs}.sim") do
    sim = Simulator.new :stocks => stocks,
                        :drop   => drop,
                        :m      => m,
                        :b      => b,
                        :after  => "1 jan #{year}",
                        :before => "31 dec #{year}"
    sim.run.map {|r| dehydrate r }
  end.map {|r| hydrate r }
end

