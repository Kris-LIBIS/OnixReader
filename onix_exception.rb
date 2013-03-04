# coding: utf-8

class OnixException < Exception

  attr_reader :code

  def initialize(code,message)
    super message
    @code = code
  end

end