# REQUIRES: mips
# Check that relocatable object produced by LLD has zero gp0 value.

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux %s -o %t.o
# RUN: ld.lld -r -o %t-rel.o %t.o
# RUN: llvm-readobj -mips-reginfo %t-rel.o | FileCheck --check-prefix=REL %s

# RUN: ld.lld -shared -o %t.so %S/Inputs/mips-gp0-non-zero.o
# RUN: llvm-readobj -mips-reginfo %t.so | FileCheck --check-prefix=DSO %s
# RUN: llvm-objdump -s -t %t.so | FileCheck --check-prefix=DUMP %s

# REL: GP: 0x0

# DSO: GP: 0x27FF0

# DUMP: Contents of section .rodata:
# DUMP:  {{[0-9a-f]+}} ffff0004 ffff0008
#                      ^ 0x10004 + 0x7ff0 - 0x27ff0
#                               ^ 0x10008 + 0x7ff0 - 0x27ff0

# DUMP: SYMBOL TABLE:
# DUMP: 00010008         .text          00000000 bar
# DUMP: 00010004         .text          00000000 foo
# DUMP: 00027ff0         .got           00000000 .hidden _gp

  .text
  .global  __start
__start:
  lw      $t0,%call16(__start)($gp)
foo:
  nop
bar:
  nop

  .section .rodata, "a"
v:
  .gpword foo
  .gpword bar
