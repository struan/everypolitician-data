require 'fuzzy_match'
require 'unicode_utils'

module Reconciliation
  # Does a fuzzy match to find existing rows that match incoming rows.
  class Fuzzer
    attr_reader :fuzzer
    attr_reader :incoming_rows
    attr_reader :instructions

    def initialize(existing_rows, incoming_rows, instructions)
      @incoming_rows = incoming_rows
      @instructions = instructions
      mapped = existing_rows.uniq { |r| r[:uuid] }.each { |r| r[:fuzzit] = UnicodeUtils.downcase(r[existing_field]) }
      @fuzzer ||= FuzzyMatch.new(
        mapped, read: :fuzzit
      )
    end

    def find_all
      incoming_rows.map do |incoming_row|
        if incoming_row[incoming_field].to_s.empty?
          warn "No #{incoming_field} in #{incoming_row.reject { |k, v| v.to_s.empty? }}".red
          next
        end
        matches = fuzzer.find_all_with_score(UnicodeUtils.downcase(incoming_row[incoming_field]))
        unless matches.any?
          warn "No fuzzed matches for #{incoming_row.reject { |k, v| v.to_s.empty? }}"
          next
        end
        data = {
          incoming: incoming_row,
          existing: matches.take(3),
        }
        warn "Fuzzed #{display(data)}"
        data
      end.compact
    end

    private

    def incoming_field
      instructions[:incoming_field].to_sym
    rescue NoMethodError
      raise('Need an `incoming_field` to match on')
    end

    def existing_field
      instructions[:existing_field].to_sym
    rescue NoMethodError
      raise('Need an `existing_field` to match on')
    end

    def display(row)
      {
        row[:incoming][incoming_field] => row[:existing].map do |r|
          [r[0][existing_field], r[1].to_f * 100]
        end
      }
    end
  end
end
