require 'pry'
require './market.rb'
require './script/helpers.rb'

schemes = [{:m => 0, :b => 0.6},
           {:m => -0.02, :b => 5.0}]

sim = simulator :year => 2008, :drop => -0.2
puts "loaded #{sim.assessor.holding.size} trxs"

comparison = schemes.map do |scheme|
  sim.m = scheme[:m]
  sim.b = scheme[:b]

  sells = sim.assess_sells

  puts "stats: #{scheme.inspect}"
  puts "\tmed. hold:   #{sells.map {|h| h[:hold] || 1000 }.median}"
  puts "\tmed. ROI:    #{sells.map {|h| h[:ROI] }.median}"
  puts "\tavg. ROI:    #{sells.map {|h| h[:ROI] }.mean}"

  prof = profit sells, :pieces => 30, :reinvest => true
  puts "\tskips:       #{prof[:skips].size}"
  puts "\tprofits:     15.0 -> #{prof[:cash]}"
  puts "\tcirculation: #{prof[:circulation]}"

  prof
end

binding.pry

