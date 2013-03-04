# coding: utf-8

require 'Nokogiri'
require 'singleton'
require 'json'

class OnixCodeList
  include Singleton

  CL_JSON = 'ONIX_2.1_CodeLists.json'
  CL_XSD  = 'ONIX_2.1_CodeLists.xsd'

  def self.list(name)
    self.instance.list(name)
  end

  def self.value(list_name, code)
    self.instance.value(list_name, code)
  end

  def self.lookup_subject(schema, code)
    self.instance.lookup_subject(schema, code)
  end

  def self.lookup_audience(schema, code)
    self.instance.lookup_audience(schema, code)
  end

  :private

  def list(name)
    code_list_schema[name]
  end

  def value(list_name, code)
    return nil unless code_list_schema.has_key? list_name
    code_list_schema[list_name]['values'][code]
  end

  def code_list_schema
    return @code_lists if @code_lists
    if File.exist? CL_JSON
      start = Time.now
      print "\nLoading code lists: "
      File.open(CL_JSON, 'r:UTF-8') do |f|
        @code_lists = JSON.parse(f.read)
      end
      puts " (#{Time.now - start} sec)"
      @code_lists
    else
      @code_lists = {}
      start = Time.now
      print "\nParsing code lists schema: "
      @doc = Nokogiri::XML::Document.parse(open(CL_XSD))
      #noinspection RubyResolve
      @doc.remove_namespaces!
      (@doc.root / 'simpleType').each do |simple_type|
        print '.'
        description = ''
        if (p = simple_type % 'annotation') && (p = p % 'documentation')
          description = p.text
        end
        value_list = {}
        (simple_type / 'enumeration').each do |e|
          value_list[e['value']] = (e % 'annotation' % 'documentation').text
        end
        @code_lists[simple_type['name']] = {'description' => description, 'values' => value_list} if value_list.size > 0
      end
      print " (#{Time.now - start} sec)"
      File.open(CL_JSON, 'w') do |f|
        f.write(@code_lists.to_json)
      end
      puts " (#{Time.now - start} sec)"
      @code_lists
    end
  end

  def lookup_subject(schema, code)
    case schema
      when '32'
        @nur_table = YAML.load_file('nur.yml') unless @nur_table
        @nur_table[code.to_i]
      else
        nil
    end
  end

  def lookup_audience(schema, code)
    case schema
      when '01' # ONIX
        value('List28', code)
      when '09' # AVI
        'AVI-' + code
      when '11' # AWS
        @aws_table = YAML.load_file('AWS.yml') unless @aws_table
        @aws_table[code]
      when '18' # AVI
        'AVI-' + code
      when '22' # ONIX
        value('List203', code)
      else
        code
    end
  end


end