# coding: utf-8

require 'onix_record'

class OnixReader

  attr_reader :records
  attr_reader :bad_records

  def initialize(dir)
    @dir = dir
    get_files
  end

  def list
    puts "ONIX records found in #@dir:"
    puts '======================================================'
    @records.each do |item|
      puts ''
      puts  "Filename:     #{item[:filename]}"
      record = item[:record]
      record.list
    end
    puts ''
    puts 'Bad records found:'
    puts '=================='
    @bad_records.each do |item|
      puts ''
      puts  "Filename:     #{item[:filename]}"
      puts  "Error:        #{item[:error_message]}"
    end
  end

  def get_files
    @records = []
    @bad_records = []
    Dir[@dir + '/**/*.onix'].each do |file|
      begin
        @records << { filename: file, record: OnixRecord.new(filename: file) }
      rescue OnixException => e
        @bad_records << { filename: file, error_code: e.code, error_message: e.message }
      rescue Exception => e
        @bad_records << { filename: file, error_message: e.message }
      end
    end
  end

end