require 'wikisnakker'

# Takes an array of hashes containing an 'id' and 'wikidata' then returns
# wikidata information about each item.
class WikidataLookup
  attr_reader :wikidata_id_lookup

  def initialize(mapping)
    @wikidata_id_lookup = Hash[
      mapping.map { |item| [item[:wikidata], item[:id]] }
    ]
  end

  def to_hash
    information = wikidata_results.map do |result|
      [wikidata_id_lookup[result.id], fields_for(result)]
    end
    Hash[information]
  end

  private

  def wikidata_ids
    @_wikidata_ids ||= wikidata_id_lookup.keys.each do |qid|
      abort "#{qid} is not a valid Wikidata id" unless qid.start_with? 'Q'
    end
  end


  def wikidata_results
    @wikidata_results ||= Wikisnakker::Item.find(wikidata_ids)
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

