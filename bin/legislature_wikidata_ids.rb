#!/usr/bin/ruby 

require 'json'
require 'pry'
require 'csv'

# Generate a Wikidata mapping file from the existing Popolo
# (Useful if we're changing how reconciliation works, and want to
# pre-seed with existing data)

def json_from(json_file)
  JSON.parse(File.read(json_file), symbolize_names: true)
end

file = ARGV.first or abort "Usage: #$0 <popolo file>"
@popolo = json_from(file)

def wikidata_id(p)
  return if p[:identifiers].empty?
  wd = p[:identifiers].find { |i| i[:scheme] == 'wikidata' } or return
  wd[:identifier]
end

rows = @popolo[:persons].map { |p| [wikidata_id(p),p[:id]] }.reject { |r| r.first.nil? }.sort_by { |r| r.last }

puts %w(id uuid).to_csv
rows.each { |r| puts r.to_csv }
