#!/usr/bin/ruby
#
# Turns a prolog symbolic execution trace into pretty pretty LaTeX.

# Top call
def texify exec_trace
  document_text = ""
  File.open "preamble.tex" do |file|
    while line = file.gets
      document_text += line
    end
  end
  document_text += "\\begin{document}\n"
  stages = get_stages exec_trace
  stages.each do |stage|
    document_text += "\\begin{frame}\n\n"
    document_text += state_text stage.i_heap, stage.i_store
    document_text += "\n"
    document_text += "Current command: "
    document_text += "\\il{#{stage.text}}"
    document_text += "\n"
    document_text += "\\vspace{1cm}\n\n"
    document_text += state_text stage.f_heap, stage.f_store
    document_text += "\\end{frame}"
    document_text += "\n"
  end
  document_text += "\\end{document}"
end

class Stage
  attr_reader :i_heap
  attr_reader :i_store
  attr_reader :f_heap
  attr_reader :f_store
  attr_reader :text
  # Each of the parameters is a string, gets converted to a more
  # appropriate representation.
  def initialize i_heap, i_store, f_heap, f_store, text
    @i_heap = {}
    @i_store= {}
    @f_heap = {}
    @f_store= {}
    @text = text
    process_pair_list i_heap,  @i_heap
    process_pair_list i_store, @i_store
    process_pair_list f_heap,  @f_heap
    process_pair_list f_store, @f_store
  end

  # turns a string list of pairs into a hash. input format:
  # [(x, 1), (y, 2)]
  def process_pair_list list, hash
    list = list[1..-2] # Remove square brackets
    if list.class == NilClass
      list = ""
    end
    array = list.split /\s*,\s*\(/
    array.each do |pair|
      pair.delete! "("
      pair.delete! ")"
      components = pair.split /\s*,\s*/
      hash[components[0]] = components[1]
    end
  end

  def pp
    puts @text
    puts @i_store
    puts @i_heap
    puts @f_store
    puts @f_heap
  end
end

# Returns an array of stages of symbolic execution. Each stage
# corresponds to a single command
def get_stages exec_trace
  ret_array = []
  lines = exec_trace.split /\n/
  current_line = 0
  # Skip past preamble
  until lines[current_line] =~ /M@/
    current_line += 1
  end
  pattern = /M@(\w+)/
  while current_line < lines.length
    if lines[current_line].match pattern
      command = lines[current_line].sub pattern, '\1'
      case command
      when "assign"
        var     = lines[current_line += 1]
        exp     = lines[current_line += 1]
        i_store = lines[current_line += 1]
        i_heap  = lines[current_line += 1]
        f_store = lines[current_line += 1]
        f_heap  = lines[current_line += 1]
        text    = "#{var} := #{exp}"
        ret_array.push Stage.new i_heap, i_store, f_heap, f_store, text
        current_line += 1
      when "new"
        var     = lines[current_line += 1]
        exp     = lines[current_line += 1]
        i_store = lines[current_line += 1]
        i_heap  = lines[current_line += 1]
        f_store = lines[current_line += 1]
        f_heap  = lines[current_line += 1]
        text    = "#{var} := new(#{exp})"
        ret_array.push Stage.new i_heap, i_store, f_heap, f_store, text
        current_line += 1
      when "dispose"
        var     = lines[current_line += 1]
        i_store = lines[current_line += 1]
        i_heap  = lines[current_line += 1]
        f_store = lines[current_line += 1]
        f_heap  = lines[current_line += 1]
        text    = "free(#{var})"
        ret_array.push Stage.new i_heap, i_store, f_heap, f_store, text
        current_line += 1
      when "lookup"
        var1    = lines[current_line += 1]
        var2    = lines[current_line += 1]
        i_store = lines[current_line += 1]
        i_heap  = lines[current_line += 1]
        f_store = lines[current_line += 1]
        f_heap  = lines[current_line += 1]
        text    = "#{var1} := [#{var2}]"
        ret_array.push Stage.new i_heap, i_store, f_heap, f_store, text
        current_line += 1
      when "mutate"
        var     = lines[current_line += 1]
        exp     = lines[current_line += 1]
        i_store = lines[current_line += 1]
        i_heap  = lines[current_line += 1]
        f_store = lines[current_line += 1]
        f_heap  = lines[current_line += 1]
        text    = "[#{var}] := #{exp}"
        ret_array.push Stage.new i_heap, i_store, f_heap, f_store, text
        current_line += 1
      when "conditional"
        bool    = lines[current_line += 1]
        i_store = lines[current_line += 1]
        i_heap  = lines[current_line += 1]
        prog    = lines[current_line += 1]
        text    = "if #{bool} (taking branch: #{prog})"
        ret_array.push Stage.new i_heap, i_store, i_heap, i_store, text
        current_line += 1
      else
        raise "command did not match"
      end
    else
      raise "line #{lines[current_line]} didn't match"
    end
  end
  ret_array
end

# Returns TikZ markup for drawing a diagram of a store and heap.
# Store and heap are hashes.
def state_text heap, store
  ret  = "\\begin{tikzpicture}"
  ret += "[->,>=triangle 45,auto,semithick,node distance=2.0cm]\n"
  first_var = nil
  last_var  = nil
  # Build store
  store.each do |var, val|
    pos_text =   "            "
    if first_var
      pos_text = "[right of=#{last_var}]"
    else
      first_var = var
    end
    last_var = var
    ret += "  \\node[var] (#{var}) #{pos_text} "
    ret += "{\\il{#{var}} \\nodepart{lower} #{val}};\n"
  end
  first_add = nil
  last_add  = nil
  # Build heap
  heap.each do |add, val|
    pos_text =   "             "
    if first_add
      pos_text = "[right of=#{last_add}]"
    else
      first_add = add
      if first_var
        pos_text = "[below of=#{first_var}]"
      end
    end
    last_add = add
    ret += "  \\node[hea] (#{add}) #{pos_text} "
    ret += "{\\il{#{add}} \\nodepart{second} #{val}};\n"
  end
  # Draw pointers
  store.each do |s_var, s_val|
    heap.each do |h_add, h_val|
      if s_val == h_add
        ret += "  \\path (#{s_var}) edge node {} (#{h_add});\n"
      end
    end
  end
  ret += "\\end{tikzpicture}\n"
  ret
end
