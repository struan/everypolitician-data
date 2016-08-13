require 'csv'
require 'rcsv'

# Encapsulates the 'data-ids' files that tie
# incoming source IDs to our UUIDs
#
# TODO: Add the 'give me a new UUID' logic here

class UuidMapFile
  def initialize(filename)
    @filename = filename
  end

  def mapping
    return {} unless @filename.exist?
    raw = @filename.read
    return {} if raw.empty?
    Hash[Rcsv.parse(raw, row_as_hash: true, columns: {}).map { |r| [r['id'], r['uuid']] }]
  end

  def rewrite(data)
    @filename.parent.mkpath
    ::CSV.open(@filename, 'w') do |csv|
      csv << %i(id uuid)
      data.each { |id, uuid| csv << [id, uuid] }
    end
  end
end
