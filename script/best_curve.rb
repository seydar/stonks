require 'pry'

files = Dir['data/roi_*.txt']
data  = files.map do |f|
  txt = File.read f
  txt.split("\n").map {|l| l.split "," }
end.flatten 1

num = 127# files.size

hash = {}
data.each do |r|
  key = [r[1], r[2]] # [m, b]
  hash[key] ||= 0
  hash[key] += r[-1].to_f * r[3].to_f
end
hash.each {|k, v| hash[k] = hash[k] / num.to_f }
binding.pry

