require 'json'
require 'pry'
require 'colorize'
require 'csv'

POPOLO = 'ep-popolo-v1.0.json'.freeze
CSVOUT = 'sources/manual/legacy-ids.csv'.freeze
HEADER = "id,legacy\n".freeze

json = JSON.parse(File.read(POPOLO), symbolize_names: true)
rows = json[:persons].map { |p| [p[:id], p[:identifiers].find { |i| i[:scheme] == 'everypolitician_legacy' }[:identifier]].to_csv }.join

FileUtils.mkpath(File.dirname(CSVOUT))
File.write(CSVOUT, HEADER + rows)
