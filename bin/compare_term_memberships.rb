require 'csv'
require 'json'
require 'pry'
require 'colorize'
require 'open-uri'
require 'open-uri/cached'

TERM_MEMBERS = 'https://wdq.wmflabs.org/api?q=claim[463:%d]'.freeze

def json_from(json_file)
  JSON.parse(open(json_file).read, symbolize_names: true)
end

def api_members(qid)
  url = TERM_MEMBERS % qid.sub('Q', '')
  json = json_from(url)
  json[:items].map { |p| p.to_s.prepend 'Q' }
end

# Compare the members we have in a term, with those in Wikidata

(popolo_file = ARGV.shift) || abort('Need a Popolo file')

json = json_from(popolo_file)
json[:events].select { |e| e[:classification] == 'legislative period' }.sort_by { |e| e[:start_date] }.each do |e|
  unless e.key? :wikidata
    warn "No wikidata ID for #{e[:name]}"
    next
  end

  puts '-----------------'
  puts e[:name].to_s.blue
  puts '-----------------'

  wd_members = api_members(e[:wikidata])

  our_members = json[:memberships].select { |m| m[:legislative_period_id] == e[:id] }.uniq { |m| m[:person_id] }.map do |m|
    p = json[:persons].find { |p| p[:id] == m[:person_id] }
    { id: p[:id], name: p[:name], wikidata: (p[:identifiers] || []).find(-> { {} }) { |i| i[:scheme] == 'wikidata' }[:identifier] }
  end
  our_ids = our_members.map { |p| p[:wikidata] }.compact

  puts 'Wikidata: %d'.yellow % wd_members.count
  puts 'Popolo: %d'.yellow % our_members.count
  puts '  with Wikidata ID: %d'.cyan % our_ids.count

  overlap = our_ids & wd_members

  puts 'Overlap: %d'.magenta % overlap.count

  wd_only = wd_members - overlap
  puts 'Only in Wikidata:'.green unless wd_only.size.zero?
  wd_only.each { |wid| puts "https://www.wikidata.org/wiki/#{wid}" }

  us_only = our_members.reject { |m| overlap.include? m[:wikidata] }
  puts 'Only in Popolo:'.green unless us_only.size.zero?
  us_only.each { |m| puts m }
end
