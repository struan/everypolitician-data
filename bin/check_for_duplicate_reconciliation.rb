require 'pry'
require 'colorize'
require 'csv'

#-----------------------------------------------------------------------
# Look for (and optionally remove) duplicates from a Reconciliation file
#-----------------------------------------------------------------------

def csv_load(filename)
  CSV.table(filename, converters: nil)
end

filename = ARGV.first || "sources/reconciliation/wikidata.csv" or abort "Usage: #$0 <reconciliation file>"

data = csv_load(filename)
by_wdid = data.group_by { |r| r[:id] }
by_uuid = data.group_by { |r| r[:uuid] }

too_many_wdid = by_uuid.select { |_, rs| rs.count > 1 }
if too_many_wdid.any?
  puts "Mutliple IDs:"
  too_many_wdid.each do |uuid, rs|
    puts "  #{uuid}: → #{rs.map { |r| r[:id] }.join(", ") }"
  end
end

too_many_uuid = by_wdid.select { |_, rs| rs.count > 1 }
if too_many_uuid.any?
  puts "Mutliple UUIDs:"
  too_many_uuid.each do |wdid, rs|
    puts "  #{wdid}: → #{rs.map { |r| r[:uuid] }.join(", ") }"
  end
end
