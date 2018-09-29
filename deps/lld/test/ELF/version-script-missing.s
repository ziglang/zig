# REQUIRES: x86

# We used to crash if a symbol in a version script was not in the symbol table.

# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: echo "{ foobar; };" > %t.script
# RUN: ld.lld --version-script %t.script -shared %t.o -o /dev/null
