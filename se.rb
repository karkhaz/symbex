#!/usr/bin/ruby
require_relative 'parser'
require_relative 'texify'
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
latex_trace = texify exec_trace
latex_file = "trace.tex"
File.open latex_file, 'w' do |file|
  file.puts latex_trace
end
system "tap #{latex_file}"
