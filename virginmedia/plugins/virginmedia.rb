#!/usr/bin/env ruby
require 'nokogiri'
require 'open-uri'

vm_operational = Nokogiri::HTML(open("http://192.168.100.1/cgi-bin/VmRouterStatusOperationCfgCgi")) do |config|
  config.options = Nokogiri::XML::ParseOptions::NOBLANKS | Nokogiri::XML::ParseOptions::NONET
end
vm_downstream = Nokogiri::HTML(open("http://192.168.100.1/cgi-bin/VmRouterStatusDownstreamCfgCgi")) do |config|
  config.options = Nokogiri::XML::ParseOptions::NOBLANKS | Nokogiri::XML::ParseOptions::NONET
end
vm_upstream = Nokogiri::HTML(open("http://192.168.100.1/cgi-bin/VmRouterStatusUpstreamCfgCgi")) do |config|
  config.options = Nokogiri::XML::ParseOptions::NOBLANKS | Nokogiri::XML::ParseOptions::NONET
end

# Filter down to the data that we are interested in
vm_download = vm_operational.css("#cableModemDownstream").first.children.children.to_a[5].children.to_a[1].children.to_a
vm_download = vm_download[2].children.to_s.split(" ")[0].to_f / 1024 / 1024
vm_upload = vm_operational.css("#cableModemDownstream").first.children.children.to_a[8].children.to_a[1].children.to_a
vm_upload = vm_upload[2].children.to_s.split(" ")[0].to_f / 1024 / 1024
vm_downstream_data = vm_downstream.css("#cableModemDownstream").first.children.children.to_a[3].children.to_a[7].children.to_a
vm_downstream_data = vm_downstream_data.values_at(* vm_downstream_data.each_index.select {|i| i.even?})
vm_upstream_data = vm_upstream.css("#cableModemDownstream").first.children.children.to_a[3].children.to_a[7].children.to_a
vm_upstream_data = vm_upstream_data.values_at(* vm_upstream_data.each_index.select {|i| i.even?})

# Clean up the data
vm_downstream_data.shift
vm_upstream_data.shift

# Build a fresh array
c = 0; vm_downstream_power_levels = Array.new
vm_downstream_data.each {|i| c += 1; vm_downstream_power_levels.push({c => i.children.to_s})}
c = 0; vm_upstream_power_levels = Array.new
vm_upstream_data.each {|i| c += 1; vm_upstream_power_levels.push({c => i.children.to_s})}

# Remove invalid enteries in fresh array
vm_downstream_power_levels_clean = Array.new
vm_downstream_power_levels.each {|i| if i.first[1].to_s != 'N/A'; vm_downstream_power_levels_clean.push(i); end }
vm_upstream_power_levels_clean = Array.new
vm_upstream_power_levels.each {|i| if i.first[1].to_s != 'N/A'; vm_upstream_power_levels_clean.push(i); end }

# Build nagios format output
speed = "download=#{vm_download.round(2)} Mb;;;; upload=#{vm_upload.round(2)} Mb;;;; "
m = nil; a = nil
vm_downstream_power_levels_clean.each {|p| m = m.to_s + 'downstream.' + p.first[0].to_s + '=' + p.first[1].to_s + ';;;; '; a = a.to_f + p.first[1].to_f }
downstream = "#{m}downstream.average=#{(a.to_f / vm_downstream_power_levels_clean.count).round(2)};;;; downstream.channels=#{vm_downstream_power_levels_clean.count};;;; "
m = nil; a = nil
vm_upstream_power_levels_clean.each {|p| m = m.to_s + 'upstream.' + p.first[0].to_s + '=' + p.first[1].to_s + ';;;; '; a = a.to_f + p.first[1].to_f }
upstream = "#{m}upstream.average=#{(a.to_f / vm_upstream_power_levels_clean.count).round(2)};;;; upstream.channels=#{vm_upstream_power_levels_clean.count};;;; "

# Print out the response
puts "OK | #{speed}#{downstream}#{upstream}"
