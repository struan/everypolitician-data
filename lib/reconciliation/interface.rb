module Reconciliation
  # Produce an HTML interface for reconciling incoming data
  class Interface
    attr_reader :merged_rows
    attr_reader :incoming_data
    attr_reader :previously_reconciled
    attr_reader :merge_instructions

    def initialize(merged_rows, incoming_data, previously_reconciled, merge_instructions)
      @merged_rows = merged_rows
      @incoming_data = incoming_data
      @previously_reconciled = previously_reconciled
      @merge_instructions = merge_instructions
    end

    def html
      template.render
    end

    private

    def template
      @template ||= Template.new(
        matched: matched,
        reconciled: previously_reconciled,
        incoming_field: merge_instructions[:incoming_field],
        existing_field: merge_instructions[:existing_field]
      )
    end

    def need_reconciling
      @need_reconciling ||= incoming_data.find_all do |d|
        matcher.find_all(d).to_a.empty? && !previously_reconciled.any? do |r|
          r[:id].to_s == d[:id]
        end
      end
    end

    def matched
      @matched ||= fuzzer.score_all.sort_by { |row| row[:existing].first[1] }.reverse
    end

    def fuzzer
      @fuzzer ||= Fuzzer.new(merged_rows, need_reconciling, merge_instructions)
    end

    def matcher
      @matcher ||= Matcher::Reconciled.new(merged_rows, merge_instructions, previously_reconciled)
    end
  end
end
