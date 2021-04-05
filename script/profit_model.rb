require 'pry'
require './market.rb'
require './script/helpers.rb'

schemes = [{:m =>  0.00, :b => 0.6}]

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

  prof = profit sells, :circulation => 15.0, :pieces => 30.0, :reinvest => true
  puts "\tskips:       #{prof[:skips].size}"
  puts "\tprofits:     15.0 -> #{prof[:cash]}"
  puts "\tcirculation: #{prof[:circulation]}"

  prof
end

binding.pry

