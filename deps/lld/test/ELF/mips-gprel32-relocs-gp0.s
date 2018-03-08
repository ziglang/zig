# Check that relocatable object produced by LLD has zero gp0 value.
# Also check an error message if input object file has non-zero gp0 value
# and the linker generates a relocatable object.
# mips-gp0-non-zero.o is a relocatable object produced from the asm code
# below and linked by GNU bfd linker.

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux %s -o %t.o
# RUN: ld.lld -r -o %t-rel.o %t.o
# RUN: llvm-readobj -mips-reginfo %t-rel.o | FileCheck --check-prefix=REL %s

# RUN: ld.lld -shared -o %t.so %S/Inputs/mips-gp0-non-zero.o
# RUN: llvm-readobj -mips-reginfo %t.so | FileCheck --check-prefix=DSO %s
# RUN: llvm-objdump -s -t %t.so | FileCheck --check-prefix=DUMP %s

# RUN: not ld.lld -r -o %t-rel.o %S/Inputs/mips-gp0-non-zero.o 2>&1 \
# RUN:   | FileCheck --check-prefix=ERR %s

# REQUIRES: mips

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

# ERR: error: {{.*}}mips-gp0-non-zero.o: unsupported non-zero ri_gp_value

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
