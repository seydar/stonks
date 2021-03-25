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

def cache(fname, &blk)
  if File.exists? fname
    return Marshal.load(File.read(fname))
  else
    res = blk.call
    open(fname, "w") {|f| f.write Marshal.dump(res) }
    res
  end
end

