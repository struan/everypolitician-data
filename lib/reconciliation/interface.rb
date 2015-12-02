module Reconciliation
  # Interface for reconciling incoming data
  class Interface
    attr_reader :merged_rows
    attr_reader :incoming_data
    attr_reader :merger

    def initialize(merged_rows, incoming_data, merger)
      @merged_rows = merged_rows
      @incoming_data = incoming_data
      @merger = merger
    end

    def generate!
      return unless merger[:reconciliation_file]

      FileUtils.mkdir_p(File.dirname(csv_file))
      File.write(html_file, template.render)
      if need_reconciling.any?
        warn "#{need_reconciling.size} out of #{incoming_data.size} rows " \
          'not reconciled'.red
      end
      return if csv_file_exists?
      warn "Need to create #{csv_file}".cyan
      abort "Created #{html_file} — please check it and re-run".green
    end

    def reconciled
      reconciled = CSV::Table.new([])
      reconciled = CSV.table(csv_file, converters: nil) if csv_file_exists?
      reconciled
    end

    private

    def template
      @template ||= Template.new(
        matched: matched,
        reconciled: reconciled,
        incoming_field: merger[:incoming_field],
        existing_field: merger[:existing_field]
      )
    end

    def need_reconciling
      @need_reconciling ||= incoming_data.find_all do |d|
        reconciler.find_all(d).to_a.empty? && !reconciled.any? do |r|
          r[:id].to_s == d[:id]
        end
      end
    end

    def csv_file_exists?
      csv_file && File.exist?(csv_file)
    end

    def csv_file
      return unless merger[:reconciliation_file]
      @csv_file ||= File.join('sources', merger[:reconciliation_file])
    end

    def html_file
      @html_file ||= csv_file.gsub('.csv', '.html')
    end

    def matched
      @matched ||= fuzzer.find_all.sort_by { |row| row[:existing].first[1] }.reverse
    end

    def fuzzer
      @fuzzer ||= Fuzzer.new(merged_rows, need_reconciling, merger)
    end

    def reconciler
      @reconciler ||= Reconciler.new(merged_rows, merger, reconciled)
    end
  end
end
