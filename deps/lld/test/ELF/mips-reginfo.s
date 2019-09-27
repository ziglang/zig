# REQUIRES: mips
# Check MIPS .reginfo section generation.

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux %s -o %t1.o
# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux \
# RUN:         %S/Inputs/mips-dynamic.s -o %t2.o
# RUN: ld.lld %t1.o %t2.o --gc-sections -shared -o %t.so
# RUN: llvm-readobj --symbols --mips-reginfo %t.so | FileCheck %s

  .text
  .globl  __start
__start:
    lw   $t0,%call16(g1)($gp)

# CHECK:      Name: _gp
# CHECK-NEXT: Value: 0x[[GP:[0-9A-F]+]]

# CHECK:      MIPS RegInfo {
# CHECK-NEXT:   GP: 0x[[GP]]
# CHECK-NEXT:   General Mask: 0x10000101
# CHECK-NEXT:   Co-Proc Mask0: 0x0
# CHECK-NEXT:   Co-Proc Mask1: 0x0
# CHECK-NEXT:   Co-Proc Mask2: 0x0
# CHECK-NEXT:   Co-Proc Mask3: 0x0
# CHECK-NEXT: }
