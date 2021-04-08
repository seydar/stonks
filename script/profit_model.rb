require 'pry'
require './market.rb'
require './script/helpers.rb'

schemes = [{:m => -0.02,  :b => 5.2}]

sim = Simulator.new
sim.assessor.holding = (ARGV[0]..(ARGV[1] || ARGV[0])).inject([]) do |sum, year|
  sum + holdings(:year => year, :drop => -0.2)
end

puts "loaded #{sim.assessor.holding.size} trxs"

comparison = schemes.map do |scheme|
  sim.m = scheme[:m]
  sim.b = scheme[:b]

  sells = sim.assess_sells

  puts "stats: #{scheme.inspect}"
  puts "\tmed. hold:   #{sells.map {|h| h[:hold] || 1000 }.median}"
  puts "\tmed. ROI:    #{sells.map {|h| h[:ROI] }.median}"
  puts "\tavg. ROI:    #{sells.map {|h| h[:ROI] }.mean}"
  puts "\tROI / hold:  #{sells.map {|h| h[:ROI] }.mean / sells.map {|h| h[:hold] || 1000 }.median}"

  prof = profit sells, :circulation => 10.0, :pieces => 50.0, :reinvest => true
  puts "\tskips:       #{prof[:skips].size}"
  puts "\tprofits:     10.0 -> #{prof[:cash]}"
  puts "\tcirculation: #{prof[:circulation]}"

  #puts "| #{sim.m}  | " +
  #     "#{sim.b}  | " +
  #     "#{sells.size}  | " +
  #     "#{sells.map {|h| h[:hold] || 1000 }.median} | " +
  #     "#{prof[:skips].size} | " +
  #     "#{sells.map {|h| h[:ROI] }.mean} | " +
  #     "#{prof[:cash]} |"

  prof
end

#binding.pry

