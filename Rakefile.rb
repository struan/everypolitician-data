
require 'fileutils'
require 'pathname'
require 'pry'
require 'tmpdir'
require 'json'
require_relative 'lib/git'

@HOUSES = FileList['data/*/*/Rakefile.rb'].map { |f| f.pathmap '%d' }.reject { |p| File.exist? "#{p}/WIP" }

def json_from(json_file)
  statements = 0
  json = JSON.load(File.read(json_file), lambda do |h|
    statements += h.values.select { |v| v.class == String }.count if h.class == Hash
  end, symbolize_names: true, create_additions: false)
  [json, statements]
end

def json_write(file, json)
  File.write(file, JSON.pretty_generate(json))
end

def terms_from(json, h)
  terms = json[:events].select { |o| o[:classification] == 'legislative period' }
  terms.sort_by { |t| t[:start_date].to_s }.reverse.map do |t|
    t.delete :classification
    t.delete :organization_id
    t[:slug] ||= t[:id].split('/').last
    t[:csv] = h + "/term-#{t[:slug]}.csv"
    t
  end.select { |t| File.exist? t[:csv] }
end

def name_from(json)
  orgs = json[:organizations].select { |o| o[:classification] == 'legislature' }
  raise "Wrong number of legislatures (#{orgs})" unless orgs.count == 1
  orgs.first[:name]
end

desc 'Install country-list locally'
task 'countries.json' do
  # By default we build every country, but if EP_COUNTRY_REFRESH is set
  # we only build any country that contains that string. For example:
  #    EP_COUNTRY_REFRESH=Latvia be rake countries.json

  to_build = ENV['EP_COUNTRY_REFRESH'] || 'data'

  countries = @HOUSES.group_by { |h| h.split('/')[1] }.select do |_, hs|
    hs.any? { |h| h.include? to_build }
  end

  data, = json_from('countries.json') rescue {}
  # If we know we'll need data for every country directory anyway,
  # it's much faster to pass the single directory 'data' than a list
  # of every country directory:
  commit_metadata = file_to_commit_metadata(
    to_build == 'data' ? ['data'] : countries.values.flatten
  )

  countries.each do |c, hs|
    meta_file = hs.first + '/../meta.json'
    meta = File.exist?(meta_file) ? JSON.load(File.open(meta_file)) : {}
    name = meta['name'] || c.tr('_', ' ')
    slug = c.tr('_', '-')
    country = {
      name:         name,
      # Deprecated - will be removed soon!
      country:      name,
      code:         meta['iso_code'].upcase,
      slug:         slug,
      legislatures: hs.map do |h|
        json_file = h + '/ep-popolo-v1.0.json'
        name_file = h + '/names.csv'
        remote_source = 'https://cdn.rawgit.com/everypolitician/everypolitician-data/%s/%s'
        popolo, statement_count = json_from(json_file)
        sha, lastmod = commit_metadata[json_file].values_at :sha, :timestamp
        lname = name_from(popolo)
        lslug = h.split('/').last.tr('_', '-')
        {
          name:                lname,
          slug:                lslug,
          sources_directory:   "#{h}/sources",
          popolo:              json_file,
          popolo_url:          remote_source % [sha, json_file],
          names:               name_file,
          lastmod:             lastmod,
          person_count:        popolo[:persons].size,
          sha:                 sha,
          legislative_periods: terms_from(popolo, h).each do |t|
            term_csv_sha = commit_metadata[t[:csv]][:sha]
            t[:csv_url] = remote_source % [term_csv_sha, t[:csv]]
          end,
          statement_count:     statement_count,
        }
      end,
    }
    data[data.find_index { |c| c[:name] == country[:name] }] = country
  end
  File.write('countries.json', JSON.pretty_generate(data.sort_by { |c| c[:name] }.to_a))
end

require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << 'test'
  t.test_files = FileList['test/*_test.rb']
  t.verbose = true
end

task default: :test
