require 'wikisnakker'
require 'json'
require 'rest-client'

# Takes an array of hashes containing an 'id' and 'wikidata' then returns
# wikidata information about each item.
class WikidataLookup
  attr_reader :wikidata_id_lookup

  def initialize(mapping)
    @wikidata_id_lookup = Hash[
      mapping.map { |item| [item[:id], item[:wikidata]] }
    ]
  end

  def to_hash
    information = wikidata_id_lookup.map do |id, wikidata_id|
      [id, fields_for(wikidata_results[wikidata_id])]
    end
    Hash[information]
  end

  private

  def wikidata_ids
    @_wikidata_ids ||= wikidata_id_lookup.values.uniq.each do |qid|
      abort "Missing Q-id" unless qid
      abort "#{qid} is not a valid Wikidata id" unless qid.start_with? 'Q'
    end
  end


  def wikidata_results
    @wikidata_results ||= Hash[Wikisnakker::Item.find(wikidata_ids).map { |r| [r.id, r] }]
  end

  def names_from(labels)
    labels.values.flatten.map do |label|
      {
        lang: label['language'],
        name: label['value'],
        note: 'multilingual'
      }
    end
  end

  def fields_for(result)
    {
      identifiers: [
        {
          scheme: 'wikidata',
          identifier: result.id
        }
      ],
      other_names: names_from(result.labels) + names_from(result.all_aliases),
    }.merge(other_fields_for(result))
  end

  # to override in subclasses
  def other_fields_for(result)
    {}
  end
end

class GroupLookup < WikidataLookup

  def other_fields_for(result)
    {
      links: links(result),
      image: logo(result),
      srgb:  colour(result),
    }.reject { |k, v| v.nil? }
  end

  def logo(result)
    result.P154 || result.P41
  end

  def colour(result)
    result.P465
  end


  def links(result)
    url = result.P856 or return nil
    return [
      {
        url: url.value,
        note: "website",
      }
    ]
  end
end

class P39sLookup < WikidataLookup

  def fields_for(result)
    {
      p39s: p39s(result),
    }.reject { |k, v| v.nil? }
  end


  def p39s(result)
    return nil if (p39s = result.P39s).empty?
    p39s.map do |posn|
      qualifiers = posn.qualifiers
      qual_data  = Hash[qualifiers.properties.map { |p| 
        [p, qualifiers[p].value.to_s]
      }]

      title = label = posn.value.to_s
      title += " (of #{qual_data['P642']})" if qual_data['P642']

      {
        id: posn.value.id,
        label: label,
        title: title,
        qualifiers: qual_data,
      }.reject { |_,v| v.empty? } rescue {}
    end
  end
end

class ElectionLookup < WikidataLookup

  # We don't have the normal id => uuid Hash here, 
  # but rather instructions for a Wikidata SPARQL lookup
  def initialize(instructions)
    q = "SELECT ?item WHERE { ?item wdt:P31 wd:#{instructions[:base]} . }"
    ids = wikidata_sparql(q)
    @wikidata_id_lookup = Hash[ ids.map { |id| [id, id] } ]
  end

  def other_fields_for(result)
    {
      dates: result.P585s,
      start_date: result.P580,
      end_date: result.P582,
      follows: result.P155,
      followed_by: result.P156,
      part_of: result.P361,
      office: result.P541,
      participants: result.P710s,
      successful_candidates: result.P991s,
      eligible_voters: result.P1867,
      ballots_cast: result.P1868,
    }.reject { |k, v| v.nil? || [*v].empty? }
  end

  private
  WIKIDATA_SPARQL_URL = 'https://query.wikidata.org/sparql'

  def wikidata_sparql(query)
    result = RestClient.get WIKIDATA_SPARQL_URL, params: { query: query, format: 'json' }
    json = JSON.parse(result, symbolize_names: true)
    json[:results][:bindings].map { |res| res[:item][:value].split('/').last }
  rescue RestClient::Exception => e
    abort "Wikidata query #{query.inspect} failed: #{e.message}"
  end
end

