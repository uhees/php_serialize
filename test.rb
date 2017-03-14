#!/usr/local/bin/ruby
# encoding: UTF-8

require 'test/unit'

$:.unshift "lib"
require 'php_serialize'

TestStruct = Struct.new(:name, :value)
class TestClass
  attr_accessor :name
  attr_accessor :value

  def initialize(name = nil, value = nil)
    @name = name
    @value = value
  end

  def to_assoc
    [['name', @name], ['value', @value]]
  end

  def ==(other)
    other.class == self.class and other.name == @name and other.value == @value
  end
end

ClassMap = {
  TestStruct.name.capitalize.intern => TestStruct,
  TestClass.name.capitalize.intern => TestClass
}

class TestPhpSerialize < Test::Unit::TestCase
  def self.test(ruby, php, opts = {})
    if opts[:name]
      name = opts[:name]
    else
      name = ruby.to_s
    end

    define_method("test_#{name}".intern) do
      assert_nothing_thrown do
        serialized = PHP.serialize(ruby)
        assert_equal php, serialized

        unserialized = PHP.unserialize(serialized, ClassMap)
        case ruby
        when Symbol
          assert_equal ruby.to_s, unserialized
        else
          assert_equal ruby, unserialized
        end
      end
    end
  end

  test nil, 'N;'
  test false, 'b:0;'
  test true, 'b:1;'
  test 42, 'i:42;'
  test(-42, 'i:-42;')
  test 2147483647, "i:2147483647;", :name => 'Max Fixnum'
  test(-2147483648, "i:-2147483648;", :name => 'Min Fixnum')
  test 4.2, 'd:4.2;'
  test 'test', 's:4:"test";'
  test 'ümläut_test', 's:13:"ümläut_test";'
  val = {"TEXT"=>"Мотовилихинские заводы — один из флагманов российского ВПК. Компания активно работает над диверсификацией и модернизацией своего производства. Полагаю, что стратегия развития компании до 2015 года позволит существенно улучшить показатели, и рекомендую бумаги эмитента к покупке.", "TYPE"=>"html"}
  res = "a:2:{s:4:\"TEXT\";s:514:\"Мотовилихинские заводы — один из флагманов российского ВПК. Компания активно работает над диверсификацией и модернизацией своего производства. Полагаю, что стратегия развития компании до 2015 года позволит существенно улучшить показатели, и рекомендую бумаги эмитента к покупке.\";s:4:\"TYPE\";s:4:\"html\";}"
  test val, res
  test :test, 's:4:"test";', :name => 'Symbol'
  test "\"\n\t\"", "s:4:\"\"\n\t\"\";", :name => 'Complex string'
  test [nil, true, false, 42, 4.2, 'test'], 'a:6:{i:0;N;i:1;b:1;i:2;b:0;i:3;i:42;i:4;d:4.2;i:5;s:4:"test";}',
    :name => 'Array'
  test({'foo' => 'bar', 4 => [5,4,3,2]}, 'a:2:{s:3:"foo";s:3:"bar";i:4;a:4:{i:0;i:5;i:1;i:4;i:2;i:3;i:3;i:2;}}', :name => 'Hash')
  test TestStruct.new("Foo", 65), 'O:10:"teststruct":2:{s:4:"name";s:3:"Foo";s:5:"value";i:65;}',
    :name => 'Struct'
  test TestClass.new("Foo", 65), 'O:9:"testclass":2:{s:4:"name";s:3:"Foo";s:5:"value";i:65;}',
    :name => 'Class'

  def test_unserialize_unknown_class
    php = 'O:12:"unknownclass":2:{s:4:"name";s:3:"Foo";s:5:"value";i:65;}'
    ruby = OpenStruct.new('name' => "Foo", 'value' => 65);
    unserialized = PHP.unserialize(php);
    assert_equal ruby, unserialized
  end

  # Verify assoc is passed down calls.
  # Slightly awkward because hashes don't guarantee order.
  def test_assoc
    assert_nothing_raised do
      ruby = {'foo' => ['bar','baz'], 'hash' => {'hash' => 'smoke'}}
      ruby_assoc = [['foo', ['bar','baz']], ['hash', [['hash','smoke']]]]
      phps = [
        'a:2:{s:4:"hash";a:1:{s:4:"hash";s:5:"smoke";}s:3:"foo";a:2:{i:0;s:3:"bar";i:1;s:3:"baz";}}',
        'a:2:{s:3:"foo";a:2:{i:0;s:3:"bar";i:1;s:3:"baz";}s:4:"hash";a:1:{s:4:"hash";s:5:"smoke";}}'
      ]
      serialized = PHP.serialize(ruby, true)
      assert phps.include?(serialized)
      unserialized = PHP.unserialize(serialized, true)
      assert_equal ruby_assoc.sort, unserialized.sort
    end
  end

  def test_sessions
    assert_nothing_raised do
      ruby = {'session_id' => 42, 'user_data' => {'uid' => 666}}
      phps = [
        'session_id|i:42;user_data|a:1:{s:3:"uid";i:666;}',
        'user_data|a:1:{s:3:"uid";i:666;}session_id|i:42;'
      ]
      unserialized = PHP.unserialize(phps.first)
      assert_equal ruby, unserialized
      serialized = PHP.serialize_session(ruby)
      assert phps.include?(serialized)
    end
  end
  
  def test_non_word_characters_in_keys
    ruby = { 'dotted.key' => 'value' }
    php = 'dotted.key|s:5:"value";'
    assert_equal ruby, PHP.unserialize(php)
  end
end

if RUBY_VERSION =~ /1.9/
  require 'test/unit/diff'
  require 'test/unit/autorunner'
  Test::Unit::AutoRunner.default_runner = "console"
else
  require 'test/unit/ui/console/testrunner'
  Test::Unit::UI::Console::TestRunner.run(TestPhpSerialize)
end
