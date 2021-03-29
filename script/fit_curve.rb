require './market.rb'
require './script/helpers.rb'
require 'pry'

####################
# Informational output is sent to STDERR because this program is meant
# to be piped into a file for later processing.
####################

sim = Simulator.new :stocks => NYSE,
                    :drop   => -0.3,
                    :after  => "1 jan #{ARGV[0]}",
                    :before => "31 dec #{ARGV[0]}"

0.00.step(:to => 0.1, :by => 0.005) do |m|
  m = -m

  0.step(:to => 6, :by => 0.1) do |b|
    STDERR.puts "m = #{m}, b = #{b}"

    sim.m = m
    sim.b = b
    sells = sim.run

    sells.each do |h|
      h[:max] = if h[:hold]
                  h[:buy].max_rise_over(h[:hold] + 30)
                else
                  [nil, -1]
                end
    end
    
    # filter out the crazy stocks that'll throw off the value
    sells = sells.filter {|h| h[:ROI] < 6 }
    
    # why don't i just use `#median` instead of `#mean`?
    size       = sells.size
    max_roi    = sells.map {|h| h[:max][1] }
    max_roi  &&= max_roi.mean
    mean_roi   = sells.map {|h| h[:ROI] }
    mean_roi &&= mean_roi.mean
    
    puts [ARGV[0].to_i, m, b, size, max_roi, mean_roi].join(",")
  end
end
