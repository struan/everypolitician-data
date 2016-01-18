require 'json'
require 'pry'
require 'colorize'

# Information about the current members of a given legislature

def json_from(json_file)
  JSON.parse(File.read(json_file), symbolize_names: true)
end

file = ARGV.first or abort "Usage: #$0 <popolo file>"
@popolo = json_from(file)

people = @popolo[:persons].group_by { |p| p[:id] }

current_term = @popolo[:events].select { |e| e[:classification] == 'legislative period' }.sort_by { |e| e[:start_date] }.last[:id]
current = @popolo[:memberships].select { |m| m[:legislative_period_id] == current_term && m[:end_date].to_s.empty? }.map { |m| people[ m[:person_id] ].first }
total = current.count

puts "TOTAL: #{total}".green

totalise = ->(count) { "%s (%0.1f%%)" % [ count, count.to_f / total * 100 ] }
has_column_value = ->(column) { current.partition { |p| !p[column.to_sym].to_s.empty? }.first.count }
has_identifier = ->(type) { current.partition { |p| (p[:identifiers] || []).find { |i| i[:scheme] == type.to_s } }.first.count }
has_link = ->(type) { current.partition { |p| (p[:links] || []).find { |i| i[:note].downcase == type.to_s.downcase } }.first.count }

puts "Email: #{totalise.(has_column_value.(:email))}"
puts "Facebook: #{totalise.(has_link.(:facebook))}"
puts "Twitter: #{totalise.(has_link.(:twitter))}"
puts "Wikidata: #{totalise.(has_identifier.(:wikidata))}"
puts "Freebase: #{totalise.(has_identifier.(:freebase))}"
puts "DOB: #{totalise.(has_column_value.(:birth_date))}"
puts "Gender: #{totalise.(has_column_value.(:gender))}"
puts "Image: #{totalise.(has_column_value.(:image))}"

