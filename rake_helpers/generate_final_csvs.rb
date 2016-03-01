require 'everypolitician/popolo'

desc "Build the term-table CSVs"
task :csvs => ['term_csvs:term_tables', 'term_csvs:name_list', 'term_csvs:positions', 'term_csvs:reports']

CLEAN.include('term-*.csv', 'names.csv')

namespace :term_csvs do

  require 'csv'
  task :term_tables => 'ep-popolo-v1.0.json' do
    @json = JSON.parse(File.read('ep-popolo-v1.0.json'), symbolize_names: true )
    popolo = EveryPolitician::Popolo.read('ep-popolo-v1.0.json')
    persons = popolo.persons
    terms = {}

    data = @json[:memberships].find_all { |m| m.key? :legislative_period_id }.map do |m|
      person = persons.find        { |r| (r[:id] == m[:person_id])       || (r[:id].end_with? "/#{m[:person_id]}") }
      group  = @json[:organizations].find { |o| (o[:id] == m[:on_behalf_of_id]) || (o[:id].end_with? "/#{m[:on_behalf_of_id]}") }
      house  = @json[:organizations].find { |o| (o[:id] == m[:organization_id]) || (o[:id].end_with? "/#{m[:organization_id]}") }
      terms[m[:legislative_period_id]] ||= @json[:events].find { |e| e[:id].split('/').last == m[:legislative_period_id].split('/').last }

      if group.nil?
        puts "No group for #{m}"
        binding.pry
        next
      end

      {
        id: person.id.split('/').last,
        name: person.name_at(m[:end_date] || terms[m[:legislative_period_id]][:end_date]),
        sort_name: person.sort_name,
        email: person.email,
        twitter: person.twitter,
        facebook: person.facebook,
        group: group[:name],
        group_id: group[:id].split('/').last,
        area_id: m[:area_id],
        area: m[:area_id] && @json[:areas].find { |a| a[:id] == m[:area_id] }[:name],
        chamber: house[:name],
        term: m[:legislative_period_id].split('/').last,
        start_date: m[:start_date],
        end_date: m[:end_date],
        image: person.image,
        gender: person.gender,
      }
    end
    data.group_by { |r| r[:term] }.each do |t, rs|
      filename = "term-#{t}.csv"
      header = rs.first.keys.to_csv
      rows   = rs.sort_by { |r| [r[:name], r[:id], r[:start_date].to_s] }.map { |r| r.values.to_csv }
      csv    = [header, rows].compact.join
      warn "Creating #{filename}"
      File.write(filename, csv)
    end
  end

  task :name_list => :term_tables do
    names = @json[:persons].map { |p|
      nameset = Set.new([p[:name]])
      nameset.merge (p[:other_names] || []).map { |n| n[:name] }
      nameset.map { |n| [n, p[:id].split('/').last] }
    }.flatten(1).uniq { |name, id| [name.downcase, id] }.sort_by { |name, id| [name, id] }

    filename = "names.csv"
    header = %w(name id).to_csv
    csv    = [header, names.map(&:to_csv)].compact.join
    warn "Creating #{filename}"
    File.write(filename, csv)
  end

  task :reports => :term_tables do
    wikidata_persons = @json[:persons].partition { |p| (p[:identifiers] || []).find { |i| i[:scheme] == 'wikidata' } }
    wikidata_parties = @json[:organizations].select { |o| o[:classification] == 'party' }.partition { |p| (p[:identifiers] || []).find { |i| i[:scheme] == 'wikidata' } }
    warn "Wikidata Persons: #{wikidata_persons.first.count} ✓ | #{wikidata_persons.last.count} ✘"
    wikidata_persons.last.shuffle.take(10).each { |p| warn "  Missing: #{ p[:name] }" } if wikidata_persons.first.count > 0 
    warn "Wikidata Parties: #{wikidata_parties.first.count} ✓ | #{wikidata_parties.last.count} ✘"
    wikidata_parties.last.each { |p| warn "  Missing: #{p[:name]} (#{p[:id]})" } if wikidata_parties.first.count > 0 && wikidata_parties.last.count <= 5
  end

  desc 'Build the Positions file'
  task :positions => ['ep-popolo-v1.0.json'] do

    positions_raw = 'sources/wikidata/positions.json'
    next unless File.exists? positions_raw

    filter_file   = 'sources/manual/position-filter.json'
    position_file = "unstable/positions.csv"
    warn "Creating #{position_file}"

    positions = JSON.parse(File.read(positions_raw), symbolize_names: true) 
    filter    = if File.exist?(filter_file) 
      JSON.parse(File.read(filter_file), symbolize_names: true).each do |s, fs|
        fs.each { |_,fs| fs.each { |f| f.delete :count } }
      end
    else 
      { exclude: { self: [], other: [] }, include: { self: [], other_legislatures: [], executive: [], party: [], other: [] } }
    end
    to_include = filter[:include].map { |_, fs| fs.map { |f| f[:id] } }.flatten.to_set
    to_exclude = filter[:exclude].map { |_, fs| fs.map { |f| f[:id] } }.flatten.to_set

    want, unknown = @json[:persons].map { |p| 
      (p[:identifiers] || []).find_all { |i| i[:scheme] == 'wikidata' }.map { |id|
        positions[id[:identifier].to_sym].to_a.map { |posn| 
          {
            id: p[:id],
            wikidata: id[:identifier],
            name: p[:name],
            position_id: posn[:id],
            position: posn[:label],
            start_date: (posn[:qualifiers] || {})[:P580],
            end_date: (posn[:qualifiers] || {})[:P582],
          }
        }
      }
    }.flatten(2).reject { |r| to_exclude.include? r[:position_id] }.partition { |r| to_include.include? r[:position_id] }

    (filter[:unknown] ||= {})[:unknown] = unknown.
      group_by { |u| u[:position_id] }.
      sort_by { |u, us| us.count }.reverse.
      map { |id, us| { id: id, name: us.first[:position], count: us.count, example: us.first[:wikidata] } }.each do |u|
        warn "  Unknown position (x#{u[:count]}): #{u[:id]} #{u[:name]} — e.g. #{u.delete :example}"
      end

    csv_columns = %w(id name position start_date end_date)
    csv    = [csv_columns.to_csv, want.map { |p| csv_columns.map { |c| p[c.to_sym] }.to_csv }].compact.join

    FileUtils.mkpath(File.dirname position_file)
    File.write(position_file, csv)
    File.write(filter_file, JSON.pretty_generate(filter))
  end
end
