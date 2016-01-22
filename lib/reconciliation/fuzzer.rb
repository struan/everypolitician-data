require 'fuzzy_match'
require 'unicode_utils'

# Given a list of existing People records (each of which must have a UUID)
# and a list of incoming People (none of which yet have UUIDs), 
# calculate potential matches from the first list for each from the second

module Reconciliation
  class Fuzzer
    attr_reader :fuzzer
    attr_reader :existing_rows
    attr_reader :incoming_rows
    attr_reader :instructions

    def initialize(existing_rows, incoming_rows, instructions)
      @existing_rows = existing_rows
      @incoming_rows = incoming_rows
      @instructions = instructions
    end

    # Ensure we only have one row per UUID, and generate for each row a
    # 'fuzzit' field that we'll be checking against. For now this just
    # defaults to the lowercase value of the 'existing_field' field
    # (usually name) — later we'll want to be able to expand this to 
    # something more complex. (e.g. multiple fields)
    #
    def existing_people
      @_existing_people ||= existing_rows.uniq { |r| r[:uuid] }.each { |r| r[:fuzzit] = UnicodeUtils.downcase(r[existing_field]) }
    end

    def fuzzer
      @_fuzzer ||= FuzzyMatch.new( existing_people, read: :fuzzit )
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
