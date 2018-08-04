# REQUIRES: mips
# Check linking MIPS code in case of -r linker's option.

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux %s -o %t.o
# RUN: ld.lld -r -o %t-r.o %t.o
# RUN: llvm-objdump -s -t %t-r.o | FileCheck %s

  .text
  .global  __start
__start:
  lw      $t0,%call16(__start)($gp)
foo:
  nop

  .section .rodata, "a"
v:
  .gpword foo

# CHECK-NOT: Contents of section .got:
# CHECK-NOT: {{.*}} _gp
