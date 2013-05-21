#!/usr/bin/ruby
#
# Abstract syntax:
# ================
#
# ASSERT       ::=  VAR |-> NUM
#               |   VAR  =  NUM
# AND_ASSERT   ::=  ASSERT & AND_ASSERT
# STAR_ASSERT  ::=  ASSERT * STAR_ASSERT
# POSTCON      ::=  AND_ASSERT @ STAR_ASSERT
# VAR          ::=  [abc..xyz]+
# NUM          ::=  [012..789]+
#

# Returns a struct containing logical and spacial assertions
def parse_assertion assertion_file
  postcond = ""
  File.open assertion_file do |file|
    postcond = file.gets
  end
  halves = postcond.split /\s*@\s*/
  ands  = halves[0]
  stars = halves[1]
  and_asserts  = []
  star_asserts = []
  (ands.split /\s*&\s*/).each   do |assertion|
    assert_string = ""
    if(m = assertion.match /\s*(\w+)\s*\|->\s*(\d+)\s*/)
       assert_string = "points_to(#{m[1]}, #{m[2]})"
    elsif(m = assertion.match /\s*(\w+)\s*=\s*(\d+)\s*/)
       assert_string = "equals(#{m[1]}, #{m[2]})"
    else
      raise "Incorrect assertion syntax (#{assertion})"
    end
    and_asserts.push assert_string
  end
  (stars.split /\s*\*\s*/).each do |assertion|
    assert_string = ""
    if(m = assertion.match /\s*(\w+)\s*\|->\s*(\d+)\s*/)
       assert_string = "points_to(#{m[1]}, #{m[2]})"
    elsif(m = assertion.match /\s*(\w+)\s*=\s*(\d+)\s*/)
       assert_string = "equals(#{m[1]}, #{m[2]})"
    else
      raise "Incorrect assertion syntax (#{assertion})"
    end
    star_asserts.push assert_string
  end
  Assertions.new and_asserts, star_asserts
end

class Assertions
  attr_reader :and_asserts, :star_asserts
  def initialize and_asserts, star_asserts
    @and_asserts  = and_asserts
    @star_asserts = star_asserts
  end
  def to_s
    ret  = "$"
    @and_asserts.each do |assert|
      ret += "#{assert.gsub /_/, ''} \\& "
    end
    ret = ret[0..-3]
    ret += " | "
    @star_asserts.each do |assert|
      ret += "#{assert.gsub /_/, ''} * "
    end
    ret = ret[0..-3]
    ret += "$"
    ret
  end
end

#asserts = parse_assertion "postcondition"
#asserts.and_asserts.each do |aa|
#  puts aa
#end
#asserts.star_asserts.each do |sa|
#  puts sa
#end
