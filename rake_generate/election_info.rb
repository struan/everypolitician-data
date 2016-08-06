
desc 'Add Wikidata elections instructions'
task :add_election_instructions do
  instructions = clean_instructions_file
  sources = instructions[:sources]
  abort 'Already have position instructions' if sources.find { |s| s[:type] == 'wikidata-elections' }
  abort 'No base: set ELECTION_BASE=Q…' unless ENV.key? 'ELECTION_BASE'

  sources << {
    file:   'wikidata/elections.json',
    type:   'wikidata-elections',
    create: {
      from: 'election-wikidata',
      base: ENV['ELECTION_BASE'],
    },
  }
  File.write(@INSTRUCTIONS_FILE, JSON.pretty_generate(instructions))
end
