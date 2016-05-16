#!/usr/bin/env ruby

require 'json'
require 'pry'
require 'csv'
require 'colorize'

# Use the output of the position-filter interface to regenerate the JSON

def json_from(json_file)
  JSON.parse(File.read(json_file), symbolize_names: true)
end

file = ARGV.shift or abort "Usage: echo CSV | #$0 <filter file>"
json = json_from(file)

csv = Hash[ARGF.readlines.map { |l| l.chomp.split(',') }]

section_for = ->(r) {
  res = csv[r[:id]] or return
  return json[:exclude][:self] if res == "Self (skip)"
  return json[:include][:other] if res == "Exclude"
  return json[:include][:self] if res == "Self (keep)"
  return json[:include][:other_legislatures] if res == "Other Legislature"
  return json[:include][:executive] if res == "Executive"
  return json[:include][:party] if res == "Party"
  return json[:include][:other] if res == "Other"
  raise "Unknown button: #{res}"
}

json[:unknown][:unknown].each do |r|
  if section = section_for.(r)
    section << r
  end
end
json[:unknown].delete :unknown

File.write(file, JSON.pretty_generate(json))
