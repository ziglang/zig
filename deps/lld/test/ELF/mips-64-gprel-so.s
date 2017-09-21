# Check setup of GP relative offsets in a function's prologue.

# RUN: llvm-mc -filetype=obj -triple=mips64-unknown-linux %s -o %t.o
# RUN: ld.lld %t.o -shared -o %t.so
# RUN: llvm-objdump -d -t %t.so | FileCheck %s

# REQUIRES: mips

# CHECK:      Disassembly of section .text:
# CHECK-NEXT: foo:
# CHECK-NEXT:    10000:    3c 1c 00 01    lui     $gp, 1
# CHECK-NEXT:    10004:    03 99 e0 2d    daddu   $gp, $gp, $25
# CHECK-NEXT:    10008:    67 9c 7f f0    daddiu  $gp, $gp, 32752

# CHECK: 0000000000027ff0   *ABS*   00000000 .hidden _gp
# CHECK: 0000000000010000   .text   00000000 foo

  .text
  .global foo
foo:
  lui     $gp,%hi(%neg(%gp_rel(foo)))
  daddu   $gp,$gp,$t9
  daddiu  $gp,$gp,%lo(%neg(%gp_rel(foo)))
