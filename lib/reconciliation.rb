require_relative './reconciliation/interface'
require_relative './reconciliation/fuzzer'
require_relative './reconciliation/template'

require 'csv'

class Reconciler

  def initialize(i)
    @instructions = i
  end

  def reconciliation_file
    fn = @instructions[:reconciliation_file] or return
    File.join('sources', fn)
  end

  def trigger_name
    File.basename(reconciliation_file, '.csv')
  end

  def triggered_by?(str)
    trigger_name.include? str
  end

  def interface_filename
    @_ifn ||= reconciliation_file.sub('.csv', '.html')
  end

  def previously_reconciled
    @_pr ||= File.exist?(reconciliation_file) ? CSV.table(reconciliation_file, converters: nil) : CSV::Table.new([])
  end

  def generate_interface!(merged_rows, incoming_data)
    interface = Reconciliation::Interface.new(merged_rows, incoming_data, previously_reconciled, @instructions)
    FileUtils.mkdir_p(File.dirname(interface_filename))
    File.write(interface_filename, interface.html)
    return interface_filename
  end

  def incoming_field
    @instructions[:incoming_field]
  end

  def existing_field
    @instructions[:existing_field]
  end
end
