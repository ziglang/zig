# Check MIPS .MIPS.options section generation.

# RUN: llvm-mc -filetype=obj -triple=mips64-unknown-linux %s -o %t1.o
# RUN: llvm-mc -filetype=obj -triple=mips64-unknown-linux \
# RUN:         %S/Inputs/mips-dynamic.s -o %t2.o
# RUN: echo "SECTIONS { \
# RUN:          . = 0x100000000; \
# RUN:          .got  : { *(.got) } }" > %t.rel.script
# RUN: ld.lld %t1.o %t2.o --gc-sections --script %t.rel.script -shared -o %t.so
# RUN: llvm-readobj -symbols -mips-options %t.so | FileCheck %s

# REQUIRES: mips

  .text
  .globl  __start
__start:
    lui  $gp, %hi(%neg(%gp_rel(g1)))

# CHECK:      Name: _gp
# CHECK-NEXT: Value: 0x[[GP:[0-9A-F]+]]

# CHECK:      MIPS Options {
# CHECK-NEXT:   ODK_REGINFO {
# CHECK-NEXT:     GP: 0x[[GP]]
# CHECK-NEXT:     General Mask: 0x10000001
# CHECK-NEXT:     Co-Proc Mask0: 0x0
# CHECK-NEXT:     Co-Proc Mask1: 0x0
# CHECK-NEXT:     Co-Proc Mask2: 0x0
# CHECK-NEXT:     Co-Proc Mask3: 0x0
# CHECK-NEXT:   }
# CHECK-NEXT: }
