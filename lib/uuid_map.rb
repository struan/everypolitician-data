require 'csv'
require 'rcsv'

# Encapsulates the 'data-ids' files that tie
# incoming source IDs to our UUIDs
#
# We're in the process of moving the location of those files, so for
# this currently checks _both_ locations for reading, but always writes
# back out to the new location
#
# TODO: Add the 'give me a new UUID' logic here

class UuidMapFile
  def initialize(pathname)
    @oldfile = pathname
    @newfile = @oldfile.parent.parent + 'idmap/' + @oldfile.basename.sub('-ids', '')
  end

  def mapping
    raw = [@newfile, @oldfile].find(&:exist?).read
    return {} if raw.empty?
    Hash[Rcsv.parse(raw, row_as_hash: true, columns: {}).map { |r| [r['id'], r['uuid']] }]
  end

  def rewrite(data)
    @oldfile.delete if @oldfile.exist?
    @newfile.parent.mkpath
    ::CSV.open(@newfile, 'w') do |csv|
      csv << %i(id uuid)
      data.each { |id, uuid| csv << [id, uuid] }
    end
  end
end
