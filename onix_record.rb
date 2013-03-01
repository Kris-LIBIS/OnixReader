# coding: utf-8

require 'nokogiri'
require 'crack'

class OnixRecord

  def initialize(options = {})
    options.merge!({index: 0}) { |_, v1, _| v1 }
    filename = options[:filename]
    raise 'No filename supplied' unless filename
    doc = Nokogiri::XML::Document.parse(open(filename))
    raise "Cannot open XML document '#{filename}'" unless @doc
    doc_hash = Crack::XML.parse(doc.to_xml)
    root = doc_hash['ONIXMessage']
    raise 'Not an ONIX document' unless root
    raise 'Not a ONIX 2.1 document' unless root['xmlns'] == 'http://www.editeur.org/onix/2.1/reference'

    @header = root['Header']

    @product = root['Product']
    if @product.is_a? Array
      @product = @product[options[:index]]
    end
    raise "Product information ##{options[:index]} not found in '#{filename}'" unless @product

  end

  def isbn
    identifier = @product['ProductIdentifier']
    return nil unless identifier
    identifier = [identifier] unless identifier.is_a? Array
    identifier.each do |id|
      return identifier['IDValue'] if identifier['ProductIDType'] == '03'
    end
  end

  def publisher
    value = []
    pub = @product['Publisher']
    return value unless pub
    pub = [pub] unless pub.is_a? Array
    pub.each do |p|
      value << p['PublisherName']
    end
  end

  def main_publisher
    pub = @product['Publisher']
    return nil unless pub
    pub = [pub] unless pub.is_a? Array
    pub[0]['PublisherName']
  end

end