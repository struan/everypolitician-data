#-----------------------------------------------------------------------
# Update the `stats.json` file for a Legislature
#-----------------------------------------------------------------------

namespace :stats do
  task regenerate: 'ep-popolo-v1.0.json' do
    popolo = Everypolitician::Popolo.read('ep-popolo-v1.0.json')
    now = DateTime.now.to_date

    events = popolo.events
    terms = events.select { |e| e.classification == 'legislative period' }
    elections = events.select { |e| e.classification == 'general election' }

    parties = popolo.organizations.select { |o| o[:classification] == 'party' }.reject { |o| o[:name].downcase == 'unknown' }
    wd_part = parties.partition { |p| (p[:identifiers] || []).find { |i| i[:scheme] == 'wikidata' } }

    # Ignore elections that are in the following year, or later
    latest_election = elections.map(&:end_date).compact.sort_by { |d| "#{d}-12-31" }.select { |d| d[0...4].to_i <= now.year }.last rescue ''
    latest_term_start = terms.last.start_date rescue ''

    if POSITION_FILTER.file?
      posns = JSON.parse(POSITION_FILTER.read, symbolize_names: true)
      executive_positions = posns[:include][:executive].count rescue 0
    else
      executive_positions = 0
    end

    stats = {
      people:    {
        count:    popolo.persons.count,
        wikidata: popolo.persons.partition { |p| (p[:identifiers] || []).find { |i| i[:scheme] == 'wikidata' } }.first.count,
      },
      groups:    {
        count:    parties.count,
        wikidata: wd_part.first.count,
      },
      terms:     {
        count:  terms.count,
        latest: latest_term_start,
      },
      elections: {
        count:  elections.count,
        latest: latest_election || '',
      },
      positions: {
        executive: executive_positions,
      },
    }

    FileUtils.mkpath('unstable')
    File.write('unstable/stats.json', JSON.pretty_generate(stats))
  end
end
