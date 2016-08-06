desc 'Add a wikidata Parties file'
task :build_parties do
  instr = clean_instructions_file
  sources = instr[:sources]
  if sources.find { |s| s[:type] == 'group' }
    warn 'Already have party instructions — rewriting'
  else
    sources << {
      file:   'wikidata/groups.json',
      type:   'group',
      create: {
        from:   'group-wikidata',
        source: 'manual/group_wikidata.csv',
      },
    }
    write_instructions(instr)
  end

  csvfile = 'sources/manual/group_wikidata.csv'
  FileUtils.mkpath('sources/manual')
  pre_mapped = if File.exist? csvfile
                 Hash[CSV.table(csvfile, converters: nil).to_a]
               else
                 {}
               end

  popolo = json_load('ep-popolo-v1.0.json')
  group_names = Hash[popolo[:organizations].map { |o| [o[:id], o[:name]] }]
  mapped, unmapped = popolo[:memberships].group_by { |m| m[:on_behalf_of_id] }.map do |m, ms|
    { id: m.sub(/^party\//, ''), count: ms.count, name: group_names[m] }
  end.sort_by { |g| g[:count] }.reverse.partition { |g| pre_mapped[g[:id]] }

  data = mapped.map { |g| [g[:id], pre_mapped[g[:id]]].to_csv }.join +
         unmapped.map { |g| [g[:id], "#{g[:name]} (x#{g[:count]})"].to_csv }.join

  File.write('sources/manual/group_wikidata.csv', "id,wikidata\n" + data)
end
