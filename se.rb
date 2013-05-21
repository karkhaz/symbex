#!/usr/bin/ruby
require_relative 'parser'
require_relative 'texify'
require_relative 'assertions'
program_file = ARGV[0]
puts "parsing..."
prolog_prog= parse_program program_file
i_heap = "[]"
i_store = "[]"
top_adrss = "-1"
puts "executing prolog query..."
query = "execute_top((#{prolog_prog}, #{top_adrss}, #{i_heap}, #{i_store}),X)"
prolog_command  = "gprolog --consult-file symbex.pl "
prolog_command += "--query-goal '#{query}, halt' "
exec_trace = `#{prolog_command}`
puts "generating latex file..."
latex_trace = texify exec_trace
verification_string = ""
if ARGV.length == 2
  # Verify assertions as well
  # Last two lines of trace should be the final store and heap
  final_heap  = (exec_trace.split /\n/)[-1]
  final_store = (exec_trace.split /\n/)[-2]
  assertions  = parse_assertion ARGV[1]
  star_asserts= assertions.star_asserts
  query = "verify(["
  (assertions.and_asserts).each do |assert|
    query += assert + ", "
  end
  query  = query[0..-3]
  query += "], ["
  (assertions.star_asserts).each do |assert|
    query += assert + ", "
  end
  query  = query[0..-3]
  query += "], #{final_store}, #{final_heap})"
  prolog_command  = "gprolog --consult-file ver.pl "
  prolog_command += "--query-goal '#{query}, halt'"
  verification_string  = "\\begin{frame}\n\n"
  verification_string += "Status of assertion #{assertions.to_s}: "
  verification_string += (`#{prolog_command}`.split /\n/)[-1]
  verification_string += "\\end{frame}\n\n"
  File.open "verout", 'w' do |file|
    file.puts verification_string
  end
end
latex_file = "trace.tex"
File.open latex_file, 'w' do |file|
  file.puts latex_trace
  file.puts verification_string
  file.puts "\\end{document}"
end
system "tap #{latex_file}"
