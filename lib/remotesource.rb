require_relative './wikidata_lookup'
require 'json'
require 'csv'

class RemoteSource

  # Instantiate correct subclass based on instructions
  def self.instantiate(i)
    c = i[:create]
    return RemoteSource::URL.new(i)             if c.key? :url
    return RemoteSource::Morph.new(i)           if c[:type] == 'morph'
    return RemoteSource::Parlparse.new(i)       if c[:type] == 'parlparse'
    return RemoteSource::OCD.new(i)             if c[:type] == 'ocd'
    return RemoteSource::Wikidata::Group.new(i) if c[:type] == 'group-wikidata'
    return RemoteSource::Wikidata::Area.new(i)  if c[:type] == 'area-wikidata'
    return RemoteSource::Wikidata::Raw.new(i)   if c[:type] == 'wikidata-raw'
    return RemoteSource::GenderBalance.new(i)   if c[:type] == 'gender-balance'
    raise "Don't know how to fetch #{i[:file]}" 
  end

  def initialize(i)
    @instructions = i
  end

  def i(k)
    @instructions[k.to_sym]
  end

  def c(k)
    i(:create)[k.to_sym]
  end

  def source
    c(:source)
  end

  def copy_url(url)
    IO.copy_stream(open(url), i(:file))
  end
  
  def regenerate
    FileUtils.mkpath File.dirname i(:file)
    write
  end
end

class RemoteSource::GenderBalance < RemoteSource
  def write
    remote = "http://www.gender-balance.org/export/#{source}"
    copy_url(remote)
  end
end

class RemoteSource::Morph < RemoteSource
  def morph_select(src, qs)
    morph_api_key = ENV['MORPH_API_KEY'] or fail 'Need a Morph API key'
    key = ERB::Util.url_encode(morph_api_key)
    query = ERB::Util.url_encode(qs.gsub(/\s+/, ' ').strip)
    url = "https://api.morph.io/#{src}/data.csv?key=#{key}&query=#{query}"
    open(url).read
  end

  def write
    data = morph_select(c(:scraper), c(:query))
    File.write(i(:file), data)
  end
end

class RemoteSource::OCD < RemoteSource
  def write
    remote = 'https://raw.githubusercontent.com/opencivicdata/ocd-division-ids/master/identifiers/' + source
    copy_url(remote)
  end
end

class RemoteSource::Parlparse < RemoteSource
  def write
    gh_url = 'https://raw.githubusercontent.com/everypolitician/everypolitician-data/master/data/'
    term_file_url = gh_url + '%s/sources/manual/terms.csv'
    instructions_url = gh_url + '%s/sources/parlparse/instructions.json'
    cwd = Dir.pwd.split("/").last(2).join("/")

    args = {
      terms_csv: term_file_url % cwd,
      instructions_json: instructions_url % cwd,
    }
    remote = 'https://parlparse-to-csv.herokuapp.com/?' + URI.encode_www_form(args)
    copy_url(remote)
  end
end

class RemoteSource::URL < RemoteSource
  def write
    copy_url(c(:url))
  end
end

class RemoteSource::Wikidata < RemoteSource
  def lookup_class
    WikidataLookup
  end

  def csv_data
    CSV.table("sources/#{source}", converters: nil)
  end

  def map_data
    csv_data.map { |r| r.to_hash }
  end

  def raw_wikidata
    lookup_class.new(map_data)
  end
  
  def processed_wikidata
    raw_wikidata.to_hash
  end

  def write
    File.write(i(:file), JSON.pretty_generate(processed_wikidata))
  end
end

class RemoteSource::Wikidata::Area < RemoteSource::Wikidata
end

class RemoteSource::Wikidata::Group < RemoteSource::Wikidata
  def lookup_class
    GroupLookup
  end
end

class RemoteSource::Wikidata::Raw < RemoteSource::Wikidata
  def lookup_class
    P39sLookup
  end

  def map_data
    super.each { |h| h[:wikidata] = h[:id] }
  end

  def processed_wikidata
    raw_wikidata.to_hash.each_with_object({}) { |(k, v), h| h[k] = v[:p39s] }.reject { |_, v| v.nil? }
  end
end

