require './market.rb'
require './script/helpers.rb'
require 'pry'

start  = Date.new(2008, 01, 01)
finish = Date.new(2021, 03, 20)

start.upto finish do |date|
  puts date
  date = Time.parse date.to_s

  # {Ticker ID => [Rank, Value]}
  rankings = Ticker.rankings :stocks => NYSE, :date => date

  #rankings.each do |tid, (rank, value)|
  #  Ranking.create :ticker_id => tid,
  #                 :rank      => rank,
  #                 :value     => value,
  #                 :date      => date
  #end

  rankings = rankings.map do |tid, (rank, value)|
    {:ticker_id => tid, :rank => rank, :value => value, :date => date}
  end

  DB[:rankings].multi_insert rankings
end

binding.pry

