
desc "Build the term-table CSVs"
task :csvs => ['term_csvs:term_tables', 'term_csvs:name_list', 'term_csvs:reports']

CLEAN.include('term-*.csv', 'names.csv')

namespace :term_csvs do

  require 'csv'

  def persons_twitter(p)
    if p.key? :contact_details
      if cd_twitter = p[:contact_details].find { |d| d[:type] == 'twitter' }
        return cd_twitter[:value].strip
      end
    end

    if p.key? 'links'
      if l_twitter = p[:links].find { |d| d[:note][/twitter/i] }
        return l_twitter[:url].strip
      end
    end
  end

  # https://twitter.com/tom_watson?lang=en
  # https://twitter.com/search?q=%23EvelynMEP&src=typd

  def standardised_twitter(t)
    return if t.to_s.empty?
    return $1 if t.match /^\@(\w+)$/
    return $1 if t.match /^(\w+)$/
    return $1 if t.match %r{(?:www.)?twitter.com/@?(\w+)$}i

    # Odd special cases
    return $1 if t.match %r{twitter.com/search\?q=%23(\w+)}i
    return $1 if t.match %r{twitter.com/#!/https://twitter.com/(\w+)}i
    return $1 if t.match %r{(?:www.)?twitter.com/#!/(\w+)[/\?]?}i
    return $1 if t.match %r{(?:www.)?twitter.com/@?(\w+)[/\/]?}i
    warn "Unknown twitter handle: #{t.to_s.magenta}"
    return 
  end

  def persons_facebook(p)
    (p[:links] || {}).find(->{{url: nil}}) { |d| d[:note] == 'facebook' }[:url]
  end

  def name_at(p, date)
    return p[:name] unless date && p.key?(:other_names)
    historic = p[:other_names].find_all { |n| n.key?(:end_date) } 
    return p[:name] unless historic.any?
    at_date = historic.find_all { |n|
      n[:end_date] >= date && (n[:start_date] || '0000-00-00') <= date
    }
    return p[:name] if at_date.empty?
    raise "Too many names at #{date}: #{at_date}" if at_date.count > 1
    
    return at_date.first[:name]
  end

  task :term_tables => 'ep-popolo-v1.0.json' do
    @json = JSON.parse(File.read('ep-popolo-v1.0.json'), symbolize_names: true )
    terms = {}

    data = @json[:memberships].find_all { |m| m.key? :legislative_period_id }.map do |m|
      person = @json[:persons].find       { |r| (r[:id] == m[:person_id])       || (r[:id].end_with? "/#{m[:person_id]}") }
      group  = @json[:organizations].find { |o| (o[:id] == m[:on_behalf_of_id]) || (o[:id].end_with? "/#{m[:on_behalf_of_id]}") }
      house  = @json[:organizations].find { |o| (o[:id] == m[:organization_id]) || (o[:id].end_with? "/#{m[:organization_id]}") }
      terms[m[:legislative_period_id]] ||= @json[:events].find { |e| e[:id].split('/').last == m[:legislative_period_id].split('/').last }

      if group.nil?
        puts "No group for #{m}"
        binding.pry
        next
      end

      {
        id: person[:id].split('/').last,
        name: name_at(person, m[:end_date] || terms[m[:legislative_period_id]][:end_date]),
        sort_name: person[:sort_name].to_s.empty? ? person[:name] : person[:sort_name],
        email: person[:email],
        twitter: standardised_twitter(persons_twitter(person)),
        facebook: persons_facebook(person),
        group: group[:name],
        group_id: group[:id].split('/').last,
        area_id: m[:area_id],
        area: m[:area_id] && @json[:areas].find { |a| a[:id] == m[:area_id] }[:name],
        chamber: house[:name],
        term: m[:legislative_period_id].split('/').last,
        start_date: m[:start_date],
        end_date: m[:end_date],
        image: person[:image],
        gender: person[:gender],
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
    wikidata_persons.last.each { |p| warn "  Missing: #{ p[:name] }" } if wikidata_persons.first.count > 0 && wikidata_persons.last.count <= 10
    warn "Wikidata Parties: #{wikidata_parties.first.count} ✓ | #{wikidata_parties.last.count} ✘"
    wikidata_parties.last.each { |p| warn "  Missing: #{ p[:name] }" } if wikidata_parties.first.count > 0 && wikidata_parties.last.count <= 5
  end

end
