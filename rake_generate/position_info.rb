
desc 'Add a wikidata P39 file'
task :build_p39s do
  instr = clean_instructions_file
  sources = instr[:sources]
  abort 'Already have position instructions' if sources.find { |s| s[:type] == 'wikidata-positions' }

  (wikidata = sources.find { |s| s[:type] == 'wikidata' }) || abort('No wikidata section')
  (reconciliation = [wikidata[:merge]].flatten(1).find { |s| s.key? :reconciliation_file }) || abort('No wikidata reconciliation file')

  sources << {
    file:   'wikidata/positions.json',
    type:   'wikidata-positions',
    create: {
      from:   'wikidata-raw',
      source: reconciliation[:reconciliation_file],
    },
  }
  write_instructions(instr)
end
