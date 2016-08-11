require_relative './reconciliation/interface'
require_relative './reconciliation/fuzzer'
require_relative './reconciliation/template'

require 'csv'

class Reconciler
  def initialize(i, t)
    @instructions = i
    @trigger = t
  end

  def filename
    (fn = @instructions[:reconciliation_file]) || return
    File.join('sources', fn)
  end

  def trigger_name
    File.basename(filename, '.csv')
  end

  def triggered?
    @trigger && trigger_name.include?(@trigger)
  end

  def interface_filename
    @_ifn ||= filename.sub('.csv', '.html')
  end

  def reconciliation_data
    raise "No reconciliation data. Rerun with GENERATE_RECONCILIATION_INTERFACE=#{trigger_name}" if previously_reconciled.empty?
    previously_reconciled
  end

  def previously_reconciled
    @_pr ||= File.exist?(filename) ? CSV.table(filename, converters: nil) : CSV::Table.new([])
  end

  def generate_interface!(merged_rows, incoming_data)
    interface = Reconciliation::Interface.new(merged_rows, incoming_data, previously_reconciled, @instructions)
    write_file!(interface_filename, interface.html)
    "Created #{interface_filename} — please check it and re-run"
  end

  def incoming_field
    @instructions[:incoming_field]
  end

  def existing_field
    @instructions[:existing_field]
  end

  private

  def write_file!(filename, text)
    FileUtils.mkdir_p(File.dirname(filename))
    File.write(filename, text)
  end
end
