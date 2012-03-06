require 'mongoid'
require 'csv'

module MongoidToCSV
  # Return full CSV content with headers as string.
  # Defined as class method which will have chained scopes applied.
  def to_csv
    csv_columns = fields.keys - %w{_type}
    fields_options = criteria.options[:fields]
    unless fields_options.nil?
      # Only check if the first field is a inclusion or exclusion, because mongoid spec
      # states only and without cannot be used together 
      if fields_options.values[0] == 1
        csv_columns = fields_options.keys.collect{|x| x.to_s}  - %w{_type}
      else
        csv_columns -= fields_options.keys.collect{|x| x.to_s}
      end
    end

    csv_columns.each { |col| @deep_column ||= col.split('.').first if col.include? '.' }
    @deep_column ||= csv_columns.first

    header_row = csv_columns.to_csv
    records_rows = all.map do |record|
      sub_rows = Array.new
      1.upto(record[@deep_column].kind_of?(Array) ? record[@deep_column].count : 1) do |i|
        sub_rows << csv_columns.map do |column|
          value = case column
            when /\./ then record[column.split('.').first][i-1][column.split('.').second]
            else record[column]
          end
          value = value.to_csv if value.respond_to?(:to_csv)
          value
        end.to_csv
      end
      sub_rows
    end.join
    header_row + records_rows
  end
end

module Mongoid::Document
  def self.included(target)
    target.extend MongoidToCSV
  end
end

# Define Relation#to_csv so that method_missing will not
# delegate to array.
class Mongoid::Relation
  def to_csv
    scoping do
      @klass.to_csv
    end
  end
end
