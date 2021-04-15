require 'fileutils'
Dir['views/*.html'].each {|f| FileUtils.mv f, "~/servers/default/public/files/#{File.basename f}" }
Dir['docs/*.html'].each {|f| FileUtils.mv f, "~/servers/default/public/files/#{File.basename f}" }

