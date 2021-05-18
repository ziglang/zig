# Insert GAS CFI directives ("control frame information") into x86-64 asm input

BEGIN {
  # don't put CFI data in the .eh_frame ELF section (which we don't keep)
  print ".cfi_sections .debug_frame"

  # only emit CFI directives inside a function
  in_function = 0

  # emit .loc directives with line numbers from original source
  printf ".file 1 \"%s\"\n", ARGV[1]
  line_number = 0

  # used to detect "call label; label:" trick
  called = ""
}

function get_const1() {
  # for instructions with 2 operands, get 1st operand (assuming it is constant)
  match($0, /-?(0x[0-9a-fA-F]+|[0-9]+),/)
  return parse_const(substr($0, RSTART, RLENGTH-1))
}

function canonicalize_reg(register) {
  if (match(register, /^r/))
    return register
  else if (match(register, /^e/))
    return "r" substr(register, 2, length(register)-1)
  else if (match(register, /[hl]$/)) # AH, AL, BH, BL, etc
    return "r" substr(register, 1, 1) "x"
  else # AX, BX, CX, etc
    return "r" register
}
function get_reg() {
  # only use if you already know there is 1 and only 1 register
  match($0, /%[er]?([abcd][xlh]|si|di|bp|8|9|10|11|12|13|14|15)/)
  return canonicalize_reg(substr($0, RSTART+1, RLENGTH-1))
}
function get_reg1() {
  # for instructions with 2 operands, get 1st operand (assuming it is register)
  match($0, /%[er]?([abcd][xlh]|si|di|bp|8|9|10|11|12|13|14|15),/)
  return canonicalize_reg(substr($0, RSTART+1, RLENGTH-2))
}
function get_reg2() {
  # for instructions with 2 operands, get 2nd operand (assuming it is register)
  match($0, /,%[er]?([abcd][xlh]|si|di|bp|8|9|10|11|12|13|14|15)/)
  return canonicalize_reg(substr($0, RSTART+2, RLENGTH-2))
}

function adjust_sp_offset(delta) {
  if (in_function)
    printf ".cfi_adjust_cfa_offset %d\n", delta
}

{
  line_number = line_number + 1

  # clean the input up before doing anything else
  # delete comments
  gsub(/(#|\/\/).*/, "")

  # canonicalize whitespace
  gsub(/[ \t]+/, " ") # mawk doesn't understand \s
  gsub(/ *, */, ",")
  gsub(/ *: */, ": ")
  gsub(/ $/, "")
  gsub(/^ /, "")
}

# check for assembler directives which we care about
/^\.(section|data|text)/ {
  # a .cfi_startproc/.cfi_endproc pair should be within the same section
  # otherwise, clang will choke when generating ELF output
  if (in_function) {
    print ".cfi_endproc"
    in_function = 0
  }
}
/^\.type [a-zA-Z0-9_]+,@function/ {
  functions[substr($2, 1, length($2)-10)] = 1
}
# not interested in assembler directives beyond this, just pass them through
/^\./ {
  print
  next
}

/^[a-zA-Z0-9_]+:/ {
  label = substr($1, 1, length($1)-1) # drop trailing :

  if (called == label) {
    # note adjustment of stack pointer from "call label; label:"
    adjust_sp_offset(8)
  }

  if (functions[label]) {
    if (in_function)
      print ".cfi_endproc"

    in_function = 1
    print ".cfi_startproc"

    for (register in saved)
      delete saved[register]
    for (register in dirty)
      delete dirty[register]
  }

  # an instruction may follow on the same line, so continue processing
}

/^$/ { next }

{
  called = ""
  printf ".loc 1 %d\n", line_number
  print
}

# KEEPING UP WITH THE STACK POINTER
# %rsp should only be adjusted by pushing/popping or adding/subtracting constants
#
/pushl?/ {
  adjust_sp_offset(8)
}
/popl?/ {
  adjust_sp_offset(-8)
}
/addl? \$-?(0x[0-9a-fA-F]+|[0-9]+),%rsp/ { adjust_sp_offset(-get_const1()) }
/subl? \$-?(0x[0-9a-fA-F]+|[0-9]+),%rsp/ { adjust_sp_offset(get_const1()) }

/call/ {
  if (match($0, /call [0-9]+f/)) # "forward" label
    called = substr($0, RSTART+5, RLENGTH-6)
  else if (match($0, /call [0-9a-zA-Z_]+/))
    called = substr($0, RSTART+5, RLENGTH-5)
}

# TRACKING REGISTER VALUES FROM THE PREVIOUS STACK FRAME
#
/pushl? %r(ax|bx|cx|dx|si|di|bp|8|9|10|11|12|13|14|15)/ { # don't match "push (%reg)"
  # if a register is being pushed, and its value has not changed since the
  #   beginning of this function, the pushed value can be used when printing
  #   local variables at the next level up the stack
  # emit '.cfi_rel_offset' for that

  if (in_function) {
    register = get_reg()
    if (!saved[register] && !dirty[register]) {
      printf ".cfi_rel_offset %s,0\n", register
      saved[register] = 1
    }
  }
}

/movl? %r(ax|bx|cx|dx|si|di|bp|8|9|10|11|12|13|14|15),-?(0x[0-9a-fA-F]+|[0-9]+)?\(%rsp\)/ {
  if (in_function) {
    register = get_reg()
    if (match($0, /-?(0x[0-9a-fA-F]+|[0-9]+)\(%rsp\)/)) {
      offset = parse_const(substr($0, RSTART, RLENGTH-6))
    } else {
      offset = 0
    }
    if (!saved[register] && !dirty[register]) {
      printf ".cfi_rel_offset %s,%d\n", register, offset
      saved[register] = 1
    }
  }
}

# IF REGISTER VALUES ARE UNCEREMONIOUSLY TRASHED
# ...then we want to know about it.
#
function trashed(register) {
  if (in_function && !saved[register] && !dirty[register]) {
    printf ".cfi_undefined %s\n", register
  }
  dirty[register] = 1
}
# this does NOT exhaustively check for all possible instructions which could
# overwrite a register value inherited from the caller (just the common ones)
/mov.*,%[er]?([abcd][xlh]|si|di|bp|8|9|10|11|12|13|14|15)$/ { trashed(get_reg2()) }
/(add|addl|sub|subl|and|or|xor|lea|sal|sar|shl|shr).*,%[er]?([abcd][xlh]|si|di|bp|8|9|10|11|12|13|14|15)$/ {
  trashed(get_reg2())
}
/^i?mul [^,]*$/ { trashed("rax"); trashed("rdx") }
/^i?mul.*,%[er]?([abcd][xlh]|si|di|bp|8|9|10|11|12|13|14|15)$/ { trashed(get_reg2()) }
/^i?div/ { trashed("rax"); trashed("rdx") }

/(dec|inc|not|neg|pop) %[er]?([abcd][xlh]|si|di|bp|8|9|10|11|12|13|14|15)/  { trashed(get_reg()) }
/cpuid/ { trashed("rax"); trashed("rbx"); trashed("rcx"); trashed("rdx") }

END {
  if (in_function)
    print ".cfi_endproc"
}
