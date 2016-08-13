require 'test_helper'
require_relative '../lib/uuid_map'

def new_tempfile
  Pathname.new(Tempfile.new(['data-ids', '.csv']).path)
end

describe 'UUID Mapper' do
  it 'has nothing in an empty tempfile' do
    UuidMapFile.new(new_tempfile).mapping.must_be_empty
  end

  it 'has new data after writing' do
    file = new_tempfile
    mapper = UuidMapFile.new(file)
    data = mapper.mapping
    data.must_be_empty
    data['fred'] = 'uuid-1'
    data['barney'] = 'uuid-2'
    mapper.rewrite(data)

    # read it back in again
    newdata = UuidMapFile.new(file).mapping
    newdata.keys.count.must_equal 2
    newdata['barney'].must_equal 'uuid-2'
  end
end
