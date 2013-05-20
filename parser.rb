#!/usr/bin/ruby
#
# Transforms programs from a whileless while language, plus heap
# extensions, into a list of prolog facts.
#
# Abstract Syntax
# ===============
# EXP      ::=  <anything> OP <anything>
# OP       ::=  + | * | - | and | or | < | > | <= | >= | = | !=
# VAR      ::=  <anything>
# COMMAND  ::=   VAR  :=  EXP
#           |    VAR  :=  new(EXP)
#           |   [VAR] :=  EXP
#           |    VAR  := [VAR]
#           |   free(VAR)
#           |   if BOOL
#                 COMMAND+
#               else
#                 COMMAND+
#               fi
#
# Proper indentation is allowed. Each command needs its own line, so no
# semicolons/other command delimiters are needed.
#
# Limitations: can't nest if statements. Expressions are binary only.

$assign_pat = /(?<var>\w+)\s+:=\s+(?<exp>.+)/
$new_pat    = /(?<var>\w+)\s+:=\s+new\((?<exp>.+)\)/
$mutate_pat = /\[(?<var>\w+)\]\s+:=\s+(?<exp>.+)/
$lookup_pat = /(?<var1>\w+)\s+:=\s+\[(?<var2>\w+)\]/
$free_pat   = /free\((?<var>\w+)\)/
$if_pat     = /if\s+(?<bool>.+)/

$plus_pat   = /(?<op1>.+)\s+\+\s+(?<op2>.+)/
$mult_pat   = /(?<op1>.+)\s+\*\s+(?<op2>.+)/
$minus_pat  = /(?<op1>.+)\s+-\s+(?<op2>.+)/

$and_pat    = /(?<op1>.+)\s+and\s+(?<op2>.+)/
$or_pat     = /(?<op1>.+)\s+or\s+(?<op2>.+)/
$lt_pat     = /(?<op1>.+)\s+<\s+(?<op2>.+)/
$gt_pat     = /(?<op1>.+)\s+>\s+(?<op2>.+)/
$le_pat     = /(?<op1>.+)\s+<=\s+(?<op2>.+)/
$ge_pat     = /(?<op1>.+)\s+>=\s+(?<op2>.+)/
$eq_pat     = /(?<op1>.+)\s+=\s+(?<op2>.+)/
$ne_pat     = /(?<op1>.+)\s+!=\s+(?<op2>.+)/

def parse_exp exp
  if(m = exp.match $plus_pat)
    "plus(#{m[:op1]}, #{m[:op2]})"
  elsif(m = exp.match $mult_pat)
    "mult(#{m[:op1]}, #{m[:op2]})"
  elsif(m = exp.match $minus_pat)
    "minus(#{m[:op1]}, #{m[:op2]})"
  elsif(m = exp.match $and_pat)
    "and(#{m[:op1]}, #{m[:op2]})"
  elsif(m = exp.match $or_pat)
    "or(#{m[:op1]}, #{m[:op2]})"
  elsif(m = exp.match $lt_pat)
    "lt(#{m[:op1]}, #{m[:op2]})"
  elsif(m = exp.match $gt_pat)
    "gt(#{m[:op1]}, #{m[:op2]})"
  elsif(m = exp.match $le_pat)
    "le(#{m[:op1]}, #{m[:op2]})"
  elsif(m = exp.match $ge_pat)
    "ge(#{m[:op1]}, #{m[:op2]})"
  elsif(m = exp.match $eq_pat)
    "eq(#{m[:op1]}, #{m[:op2]})"
  elsif(m = exp.match $ne_pat)
    "ne(#{m[:op1]}, #{m[:op2]})"
  else
    exp
  end
end

def parse_program program_file
  command_string = "["
  File.open program_file do |file|
    line_number = 0
    while line = file.gets
      line.chomp!
      if (line_number += 1) > 1
        command_string += ", "
      end
      if(m = line.match $new_pat)
        exp = parse_exp m[:exp]
        command_string += "new(#{m[:var]}, #{exp})"
      elsif(m = line.match $mutate_pat)
        exp = parse_exp m[:exp]
        command_string += "mutate(#{m[:var]}, #{exp})"
      elsif(m = line.match $lookup_pat)
        command_string += "lookup(#{m[:var1]}, #{m[:var2]})"
      elsif(m = line.match $free_pat)
        command_string += "deallocate(#{m[:var]})"
      elsif(m = line.match $assign_pat)
        exp = parse_exp m[:exp]
        command_string += "assign(#{m[:var]}, #{exp})"
      elsif(m = line.match $if_pat)
        exp = parse_exp m[:bool]
        command_string += "ifthenelse(#{exp}, ["
        line_number = 0 # No leading comma for first item in 'then' list
      elsif(line.match "else")
        command_string = command_string[0..-3] # Get rid of trailing comma
        command_string += "], ["
        line_number = 0 # No leading comma for first item in 'else' list
      elsif(line.match "fi")
        command_string = command_string[0..-3] # Get rid of trailing comma
        command_string += "])"
        # Trailing comma will be added on the next loop
      else
      end
    end
    command_string += "]"
  end
  command_string
end

# This allows the parser to be run stand-alone
#puts parse_program ARGV[0]
