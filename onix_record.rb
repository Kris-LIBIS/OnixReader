# coding: utf-8

require 'nokogiri'
require 'yaml'

class NilClass
  def %(_)
    nil
  end

  def text
    ''
  end
end

class OnixRecord

  def initialize(options = {})
    options.merge!({index: 0}) { |_, v1, _| v1 }
    filename = options[:filename]
    raise 'No filename supplied' unless filename
    doc = Nokogiri::XML::Document.parse(open(filename))
    raise "Cannot open XML document '#{filename}'" unless doc
    raise 'Not an ONIX document' unless doc.root.name == 'ONIXMessage'
    raise 'Not a ONIX 2.1 document' unless doc.root.namespace.href == 'http://www.editeur.org/onix/2.1/reference'
    @header = doc.root % 'Header'
    @product = doc.root / 'Product'
    if @product.is_a? Nokogiri::XML::NodeSet
      @product = @product[options[:index]]
    else
      raise "Product information ##{options[:index]} not found in '#{filename}'"
    end
  end

  def epub_type
    case (@product % 'EpubType').text
      when '002'
        'PDF'
      when '025'
        'TXT'
      when '029'
        'EPUB'
      else
        ''
    end
    +
    case (@product % 'EpubTypeVersion').text
      when '0'
        ''
      when '3'
        '_DRM'
      when '2'
        '_DW'
      else
        ''
    end
  end

  def isbn
    [15, 3].each do |key|
      return identifier_list[key][0] if identifier_list.has_key? key
    end
    nil
  end

  def main_title
    title_list[1][0]
  end

  def titles
    #noinspection RubyHashKeysTypesInspection
    Hash[title_list.sort].values.flatten
  end

  def main_publisher
    self.publishers[0]
  end

  def publishers
    publisher_list
  end

  def authors
    #noinspection RubyHashKeysTypesInspection
    Hash[contributor_list['A01'].sort].values.flatten
  end

  def illustrators
    #noinspection RubyHashKeysTypesInspection
    Hash[contributor_list['A12'].sort].values.flatten
  end

  def editors
    #noinspection RubyHashKeysTypesInspection
    Hash[contributor_list['B01'].sort].values.flatten
  end

  def adaptors
    #noinspection RubyHashKeysTypesInspection
    Hash[contributor_list['B05'].sort].values.flatten
  end

  def translators
    #noinspection RubyHashKeysTypesInspection
    Hash[contributor_list['B06'].sort].values.flatten
  end

#  :private

  def identifier_list
    return @identifier_list if @identifier_list
    @identifier_list = Hash.new []
    (@product / 'ProductIdentifier').each do |id|
      id_type = (id % 'ProductIDType').text.to_i
      id_value = (id % 'IDValue').text
      v = @identifier_list[id_type].dup
      v << id_value
      @identifier_list[id_type] = v
    end
    @identifier_list
  end

  def publisher_list
    return @publisher_list if @publisher_list
    @publisher_list = []
    (@product / 'Publisher').each do |pub|
      @publisher_list << (pub % 'PublisherName').text
    end
    @publisher_list
  end

  def title_list
    return @title_list if @title_list
    @title_list = Hash.new []
    (@product / 'Title').each do |t|
      t_type = (t % 'TitleType').text.to_i
      t_value = (t % 'TitleText').text
      v = @title_list[t_type].dup
      v << t_value
      @title_list[t_type] = v
    end
    @title_list
  end

  def subject_list
    return @subject_list if @subject_list
    @subject_list = Hash.new []
    (@product / 'Subject').each do |s|
      s_type = (s % 'SubjectSchemeIdentifier').text.to_i
      s_value = s % 'SubjectHeadingText' ? (s % 'SubjectHeadingText').text : lookup_subject(s_type, (s % 'SubjectCode').text)
      v = @subject_list[s_type].dup
      v << s_value
      @subject_list[s_type] = v
    end
    @subject_list
  end

  def lookup_subject(schema, code)
    case schema
      when 32
        nur_table = YAML::open('nur.yml')
        nur_table[code.to_i]
      else
        nil
    end
  end

  def contributor_list
    return @contributor_list if @contributor_list
    @contributor_list = Hash.new(Hash.new([]))
    (@product / 'Contributor').each do |c|
      c_type = (c % 'ContributorRole').text
      c_value = ''
      c_value = (c % 'PersonName').text if (c % 'PersonName')
      c_value = (c % 'PersonNameInverted').text if (c % 'PersonNameInverted')
      if c % 'KeyNames'
        c_value = [
            (c % 'TitlesBeforeNames').text,
            (c % 'NamesBeforeKey').text,
            [
                (c % 'PrefixToKey').text,
                (c % 'KeyNames').text,
                (c % 'SuffixToKey').text
            ].join,
            (c % 'NamesAfterKey').text,
            (c % 'LettersAfterNames').text,
            (c % 'TitlesAfterNames').text
        ].join(' ')
        c_value.gsub!(/\s+/,' ')
        c_value.strip!
      end
      c_index = 9999
      if (i = c % 'SequenceNumberWithinRole')
        c_index = i.text.to_i
      end
      v = @contributor_list[c_type].dup
      x = v[c_index].dup
      x << c_value
      v[c_index] = x
      @contributor_list[c_type] = v
    end
    @contributor_list
  end

end