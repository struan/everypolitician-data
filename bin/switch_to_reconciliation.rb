#!/bin/env ruby
# encoding: utf-8

#---------------------------------------------------------------------
# convert Wikidata direct-match instructions to use reconciliation
#---------------------------------------------------------------------

require 'pry'
require 'everypolitician/popolo'

def json_load(file)
  JSON.parse(open(file).read, symbolize_names: true)
end

POPOLO_FILE = 'ep-popolo-v1.0.json'
INSTRUCTIONS = 'sources/instructions.json'
RECONCILIATION = 'sources/reconciliation/wikidata.csv'
FileUtils.mkpath(File.dirname RECONCILIATION)

abort "#{POPOLO_FILE} missing" unless File.exist? POPOLO_FILE
abort "#{INSTRUCTIONS} missing" unless File.exist? INSTRUCTIONS
# abort "#{RECONCILIATION} already exists" if File.exist? RECONCILIATION

instructions = json_load(INSTRUCTIONS)
wd = instructions[:sources].find { |i| i[:type] == 'wikidata' } or
  abort "No wikidata instructions in #{INSTRUCTIONS}"
# abort "Already reconciling" if wd[:merge].key? 'reconciliation_file'

popolo = Everypolitician::Popolo.read(POPOLO_FILE)
mapped = popolo.persons.select { |p| p.wikidata }.sort_by { |p| p.id }.map { |p| "#{p.wikidata},#{p.id}" }

File.write(RECONCILIATION, "id,uuid\n" + mapped.join("\n"))

wd[:merge] = { 
  incoming_field: 'name',
  existing_field: 'name',
  reconciliation_file: 'reconciliation/wikidata.csv',
}
File.write(INSTRUCTIONS, JSON.pretty_generate(instructions))


