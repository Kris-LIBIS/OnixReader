# coding: utf-8

require 'nokogiri'
require 'yaml'

require 'onix_code_list'
require 'onix_exception'

class NilClass
  def %(_)
    nil
  end

  def /(_)
    nil
  end

  def text
    ''
  end
end

#noinspection RubyTooManyMethodsInspection,RubyHashKeysTypesInspection
class OnixRecord

  def initialize(options = {})
    @lists = {}
    options.merge!({index: 0}) { |_, v1, _| v1 }
    filename = options[:filename]
    raise OnixException.new(100, 'No filename supplied') unless filename
    doc = Nokogiri::XML::Document.parse(open(filename))
    raise OnixException(101, "Cannot open XML document '#{filename}'") unless doc
    raise OnixException(102, 'Not an ONIX document') unless doc.root.name == 'ONIXMessage'
    raise OnixException(103, 'Not a ONIX 2.1 document') unless doc.root.namespace.href == 'http://www.editeur.org/onix/2.1/reference'
    @header = doc.root % 'Header'
    @product = doc.root / 'Product'
    if @product.is_a? Nokogiri::XML::NodeSet
      @product = @product[options[:index]]
    else
      raise OnixException(104, "Product information ##{options[:index]} not found in '#{filename}'")
    end
  end

  def list
    puts "File type:    #{epub_type}"
    puts "ISBN:         #{isbn}"
    puts "Title:        #{main_title}"
    (titles - [main_title]).each do |title|
      puts "            - #{title}"
    end
    puts "Publication:  #{publication_date} (#{publication_year})"
    puts "Publisher:    #{main_publisher}"
    (publishers - [main_publisher]).each do |publisher|
      puts "            - #{publisher}"
    end
    puts "Authors:      #{authors.join '; '}"
    puts 'Contributors: '
    contributors.each do |_, val|
      puts "   - #{val[:description]}: #{val[:values].join '; '}"
    end
    puts "Genres:        #{genres.join '; '}"
    puts "Categories:    #{categories.join '; '}"
    puts "Themes:        #{themes.join '; '}"
    puts "Keywords:      #{keywords.join '; '}"
    puts 'Main subjects:'
    main_subject_list.each do |k,v|
      puts "   - #{OnixCodeList.value('List26',k)}: #{v.join '; '}"
    end
    puts 'Subjects:'
    subject_list.each do |k,v|
      puts "   - #{OnixCodeList.value('List27',k)}: #{v.join '; '}"
    end
    puts "Audience:      #{audience.join '; '}"
    puts 'Summary:'
    summary.each { |s| puts s; puts '----------' }
  end

  def epub_type
    value = []
    if (p = @product % 'EpubType')
      value << OnixCodeList.value('List10', p.text)
    end
    value << (@product % 'EpubTypeVersion').text if @product % 'EpubTypeVersion'
    value.join ' '
  end

  def isbn
    [15, 3].each do |key|
      return identifier_list[key][0] if identifier_list.has_key? key
    end
    nil
  end

  def main_title
    title_list['01'][0]
  end

  def titles
    Hash[title_list.sort].values.flatten
  end

  def publication_date
    (@product % 'PublicationDate').text
  end

  def publication_year
    publication_date[0..3]
  end

  def main_publisher
    self.publishers[0]
  end

  def publishers
    publisher_list
  end

  def contributors
    contributor_list
  end

  def authors
    #noinspection RubyArgCount
    contributor_list.select do |key, _|
      %w(A01 A02 A12 A13).include? key
    end.collect { |_, v| v[:values] }.flatten
  end

  def main_subjects
    main_subject_list.collect { |_, v| v }.flatten
  end

  def subjects
    subject_list.collect { |_, v| v }.flatten
  end

  def genres
    []
  end

  def categories
    []
  end

  def themes
    []
  end

  def keywords
    main_subject_list['20']
  end

  def audience
    audience_list
  end

  def summary
    text_list['03'][:values]
  end

#  :private

  def identifier_list
    return @lists[:identifier] if @lists[:identifier]
    @lists[:identifier] = Hash.new []
    (@product / 'ProductIdentifier').each do |id|
      id_type = (id % 'ProductIDType').text.to_i
      id_value = (id % 'IDValue').text
      v = @lists[:identifier][id_type].dup
      v << id_value
      @lists[:identifier][id_type] = v
    end
    @lists[:identifier]
  end

  def publisher_list
    return @lists[:publisher] if @lists[:publisher]
    @lists[:publisher] = []
    (@product / 'Publisher').each do |pub|
      @lists[:publisher] << (pub % 'PublisherName').text
    end
    @lists[:publisher]
  end

  def title_list
    return @lists[:title] if @lists[:title]
    @lists[:title] = Hash.new []
    (@product / 'Title').each do |t|
      t_type = (t % 'TitleType').text
      t_value = (t % 'TitleText').text
      v = @lists[:title][t_type].dup
      v << t_value
      (t / 'Subtitle').each { |s| v << s.text }
      @lists[:title][t_type] = v
    end
    @lists[:title]
  end

  def contributor_list
    return @lists[:contributor] if @lists[:contributor]
    list = Hash.new()
    (@product / 'Contributor').each do |c|
      c_type = (c % 'ContributorRole').text
      c_type_text = OnixCodeList.value('List17', c_type)
      c_type_name = c_type_text.gsub /[()]/, ''
      c_type_name.downcase!
      c_type_name.gsub! /\s/, '_'
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
        c_value.gsub!(/\s+/, ' ')
        c_value.strip!
      end
      c_index = 999
      if (i = c % 'SequenceNumberWithinRole')
        c_index = i.text.to_i
      end
      v = list.has_key?(c_type) ? list[c_type][:values] : {}
      x = v.has_key?(c_index) ? v[c_index] : []
      x << c_value
      v[c_index] = x
      list[c_type] = {name: c_type_name, description: c_type_text, values: v}
    end
    @lists[:contributor] = list.sort.each_with_object({}) do |pair, obj|
      obj[pair.first] = {
          name: pair.last[:name],
          description: pair.last[:description],
          values: Hash[pair.last[:values].sort].values.flatten
      }
    end
    @lists[:contributor]
  end

  def subject_list
    return @lists[:subject] if @lists[:subject]
    @lists[:subject] = Hash.new []
    (@product / 'Subject').each do |s|
      s_type = (s % 'SubjectSchemeIdentifier').text
      s_value = s % 'SubjectHeadingText' ? (s % 'SubjectHeadingText').text : OnixCodeList.lookup_subject(s_type, (s % 'SubjectCode').text)
      v = @lists[:subject][s_type].dup
      v << s_value
      @lists[:subject][s_type] = v
    end
    @lists[:subject]
  end

  def main_subject_list
    return @lists[:main_subject] if @lists[:main_subject]
    @lists[:main_subject] = Hash.new []
    (@product / 'MainSubject').each do |s|
      s_type = (s % 'MainSubjectSchemeIdentifier').text
      s_value = s % 'SubjectHeadingText' ? (s % 'SubjectHeadingText').text : OnixCodeList.lookup_subject(s_type, (s % 'SubjectCode').text)
      v = @lists[:main_subject][s_type].dup
      v << s_value
      @lists[:main_subject][s_type] = v
    end
    @lists[:main_subject]
  end

  def audience_list
    return @lists[:audience] if @lists[:audience]
    @lists[:audience] = []
    (@product / 'AudienceCode').each do |code|
      @lists[:audience] << OnixCodeList.value('List28', code)
    end
    (@product / 'Audience').each do |audience|
      @lists[:audience] << OnixCodeList.lookup_audience(
          (audience % 'AudienceCodeType').text,
          (audience % 'AudienceCodeValue').text
      )
    end
    @lists[:audience]
  end

  def text_list
    return @lists[:text] if @lists[:text]
    @lists[:text] = Hash.new( { description: '', values: [] } )
    (@product / 'OtherText').each do |other_text|
      t_type_code = (other_text % 'TextTypeCode').text
      t_type = OnixCodeList.value('List33', t_type_code)
      (other_text / 'Text').each do |text|
        v = @lists[:text][t_type_code].dup
        v[:description] = t_type
        v[:values] << text.text
      end
      (other_text / 'TextLink').each do |link|
        v = @lists[:text][t_type_code].dup
        v[:description] = t_type
        v[:values] << link.text
      end
    end
    @lists[:text]
  end

end