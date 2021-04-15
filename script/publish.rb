require 'fileutils'
Dir['views/*.html'].each {|f| FileUtils.cp f, File.expand_path("~/servers/default/public/files/#{File.basename f}"), :verbose => true }
['doc/stocks.html', 'doc/db.html'].each {|f| FileUtils.cp f, File.expand_path("~/servers/default/public/files/#{File.basename f}"), :verbose => true }

