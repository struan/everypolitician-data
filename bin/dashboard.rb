require 'everypolitician'
require 'everypolitician/popolo'
require 'pry'
require 'csv'

# Report some statistics for each legislature
#
# Usage: This should be passed the location of a file
# that ranks the countries (e.g. output from Google Analytics)

(analytics_file = ARGV.first) || abort("Usage: #{$PROGRAM_NAME} <analytics.csv>")
drilldown = CSV.table(analytics_file)
ordering = Hash[drilldown.select { |r| (r[0].to_s.length > 1) && (r[0][0] == r[0][-1]) }.each_with_index.map { |r, i| [r[0].delete('/'), i] }]

EveryPolitician.countries_json = 'countries.json'

data = EveryPolitician.countries.map do |c|
  # TODO: accept an argument for whether we want all legislatures
  # For now only show the largest in a country
  c.legislatures.sort_by(&:person_count).reverse.take(1).map do |l|
    statsfile = File.join(File.dirname(l.raw_data[:popolo]), 'unstable/stats.json')
    raise "No statsfile for #{c[:name]}/#{l[:name]}" unless File.exist? statsfile
    stats = JSON.parse(open(statsfile).read, symbolize_names: true)

    now = DateTime.now.to_date
    last_build = Time.at(l.lastmod.to_i).to_date

    {
      posn:                (ordering[c.slug.downcase] || 999) + 1,
      country:             c.name,
      legislature:         l.name,
      lastmod:             last_build.to_s,
      ago:                 (now - last_build).to_i,
      people:              stats[:people][:count],
      wikidata:            stats[:people][:wikidata],
      parties:             stats[:groups][:count],
      wd_parties:          stats[:groups][:wikidata],
      terms:               l.legislative_periods.count,
      elections:           stats[:elections][:count],
      latest_term:         l.legislative_periods.first.raw_data[:start_date],
      latest_election:     stats[:elections][:latest],
      executive_positions: stats[:positions][:executive],
    }
  end
end.flatten

puts data.first.keys.to_csv
data.sort_by { |h| [h[:posn], h[:country]] }.each do |h|
  puts h.values.to_csv
end
