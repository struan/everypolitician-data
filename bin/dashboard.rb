require 'everypolitician'
require 'everypolitician/popolo'
require 'pry'
require 'csv'

# Report some statistics for each legislature
#
# Usage: This should be passed the location of a file
# that ranks the countries (e.g. output from Google Analytics)

analytics_file = ARGV.first or abort "Usage: #$0 <analytics.csv>"
drilldown = CSV.table(analytics_file)
ordering = Hash[drilldown.select { |r| (r[0].to_s.length > 1) && (r[0][0] == r[0][-1]) }.each_with_index.map { |r, i| [r[0].gsub('/',''), i] }]

EveryPolitician.countries_json = 'countries.json'

data = EveryPolitician.countries.map do |c|
  c.legislatures.map do |l|
    popolo = Everypolitician::Popolo.read(l.raw_data[:popolo])
    events = popolo.events
    terms = events.select { |e| e.classification == 'legislative period' }
    elections = events.select { |e| e.classification == 'general election' }

    # Whilst we await https://github.com/everypolitician/everypolitician-popolo/pull/29
    latest_term_start = terms.last.start_date rescue ''
    latest_election = elections.last.end_date rescue ''

    last_build = Time.at(l.lastmod.to_i).to_date

    {
      posn: (ordering[ c.slug.downcase ] || 999) + 1,
      country: c.name,
      legislature: l.name,
      lastmod: last_build.to_s,
      ago: (DateTime.now.to_date - last_build).to_i,
      people: popolo.persons.count,
      wikidata: popolo.persons.partition { |p| (p[:identifiers] || []).find { |i| i[:scheme] == 'wikidata' } }.first.count,
      terms: terms.count,
      elections: elections.count,
      latest_term: latest_term_start,
      latest_election: latest_election,
    }
  end
end.flatten

puts data.first.keys.to_csv
data.sort_by { |h| [h[:posn], h[:country]] }.each do |h|
  puts h.values.to_csv
end

