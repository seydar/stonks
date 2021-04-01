require 'pry'

files = Dir['data/roi_*.txt']
data  = files.map do |f|
  txt = File.read f
  txt.split("\n").map {|l| l.split "," }
end.flatten 1

num = 135 # files.size

h = data.inject(Hash.new {|h, k| h[k] = 0 }) do |hash, row|
  hash[row[1..2]] += (row[-1].to_f * row[3].to_f) / row[3].to_f#num
  hash
end

p h.max_by {|k, v| v }

binding.pry

