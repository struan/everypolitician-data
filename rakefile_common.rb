
# We take various steps to convert all the incoming data into the output
# formats. Each of these steps uses a different rake_helper:
#

# Step 1: combine_sources
# This takes all the incoming data (mostly as CSVs) and joins them
# together into 'sources/merged.csv'

# Step 2: verify_source_data
# Make sure that the merged data has everything we need and is 
# well-formed

# Step 3: turn_csv_to_popolo
# This turns the 'merged.csv' into a 'sources/merged.json'

# Step 4: generate_ep_popolo
# This turns the generic 'merged.json' into the EP-specific
# 'ep-popolo.json' 

# Step 5: generate_final_csvs
# Generates term-by-term CSVs from the ep-popolo

# Step 6: generate_stats
# Generates statistics about the data we have

require 'colorize'
require 'csv'
require 'csv_to_popolo'
require 'erb'
require 'fileutils'
require 'fuzzy_match'
require 'json'
require 'open-uri'
require 'pathname'
require 'pry'
require 'rake/clean'
require 'set'
require 'yajl/json_gem'

MERGED_JSON = Pathname.new('sources/merged.json')
MERGED_CSV  = Pathname.new('sources/merged.csv')
POSITION_FILTER = Pathname.new('sources/manual/position-filter.json')
POSITION_RAW = Pathname.new('sources/wikidata/positions.json')
POSITION_CSV = Pathname.new('unstable/positions.csv')

Numeric.class_eval { def empty?; false; end }


def deep_sort(element)
  if element.is_a?(Hash)
    element.keys.sort.each_with_object({}) { |k, newhash| newhash[k] = deep_sort(element[k]) }
  elsif element.is_a?(Array)
    element.map { |v| deep_sort(v) }
  else
    element
  end
end

def json_load(file)
  raise "No such file #{file}" unless File.exist? file
  JSON.parse(File.read(file), symbolize_names: true)
end

def json_write(file, json)
  File.write(file, JSON.pretty_generate(json))
end

module Enumerable
  # Workaround for native sort_by producing inconsistent results between OS X
  # and Linux.
  # @see https://bugs.ruby-lang.org/issues/11379
  def portable_sort_by(&block)
    group_by(&block).sort_by { |group_name, _| group_name }.flat_map { |_, group| group }
  end
end

def popolo_write(file, json)
  # TODO remove the need for the .to_s here, by ensuring all People and Orgs have names
  json[:persons] = json[:persons].portable_sort_by { |p| [ p[:name].to_s, p[:id] ] }
  json[:persons].each do |p|
    p[:identifiers]     &&= p[:identifiers].portable_sort_by { |i| [ i[:scheme], i[:identifier] ] }
    p[:contact_details] &&= p[:contact_details].portable_sort_by { |d| [ d[:type] ] }
    p[:links]           &&= p[:links].portable_sort_by { |l| l[:note] }
    p[:other_names]     &&= p[:other_names].portable_sort_by { |n| [ n[:lang].to_s, n[:name] ] }
  end
  json[:organizations] = json[:organizations].portable_sort_by { |o| [ o[:name].to_s, o[:id] ] }
  json[:memberships]   = json[:memberships].portable_sort_by { |m| [
    m[:person_id], m[:organization_id], m[:legislative_period_id], m[:start_date].to_s, m[:on_behalf_of_id].to_s, m[:area_id].to_s
  ] }
  json[:events] &&= json[:events].portable_sort_by { |e| [ e[:start_date].to_s || '', e[:id].to_s ] }
  json[:areas]  &&= json[:areas].portable_sort_by  { |a| [ a[:id] ] }
  final = Hash[deep_sort(json).sort_by { |k, _| k }.reverse]
  File.write(file, JSON.pretty_generate(final))
end

@SOURCE_DIR = 'sources/manual'
@DATA_FILE = @SOURCE_DIR + '/members.csv'
@INSTRUCTIONS_FILE = 'sources/instructions.json'

def clean_instructions_file
  json_load(@INSTRUCTIONS_FILE) || raise("Can't read #{@INSTRUCTIONS_FILE}")
end

def write_instructions(instr)
  File.write(@INSTRUCTIONS_FILE, JSON.pretty_generate(instr))
end

def load_instructions_file
  json = clean_instructions_file
  json[:sources].each do |s|
    s[:file] = "sources/%s" % s[:file] unless s[:file][/sources/]
  end
  json
end

def instructions(key)
  @instructions ||= load_instructions_file
  @instructions[key]
end

desc "Rebuild from source data"
task :rebuild => [ :clobber, 'ep-popolo-v1.0.json' ]
task :default => [ :csvs, 'stats:regenerate' ]

Dir[File.dirname(__FILE__) + '/rake_*/*.rb'].each { |file| require file }

