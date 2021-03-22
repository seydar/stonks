require '/home/ari/servers/auberge.rb'

action = ARGV[0]
stocks = ARGV[1..-1].join ", "

Auberge::Phone.sms :to => '16037297097',
                   :body => "#{action} #{stocks}"

