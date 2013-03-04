# coding: utf-8

require 'onix_reader'

class TestOnixReader

  def self.test_reader_1
    reader = OnixReader.new('G:/VEP')
    reader.list
  end

end

TestOnixReader.test_reader_1