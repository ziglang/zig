# REQUIRES: mips
# Check R_MIPS_HI16 / LO16 relocations calculation.

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux %s -o %t.o
# RUN: ld.lld %t.o -o %t.exe
# RUN: llvm-objdump -d -t %t.exe | FileCheck %s

  .text
  .globl  __start
__start:
  lui    $t0,%hi(__start)
  lui    $t1,%hi(g1)
  addi   $t0,$t0,%lo(__start+4)
  addi   $t0,$t0,%lo(g1+8)

  lui    $t0,%hi(l1+0x10000)
  lui    $t1,%hi(l1+0x20000)
  addi   $t0,$t0,%lo(l1+(-4))

  .data
  .type  l1,@object
  .size  l1,4
l1:
  .word 0

  .globl g1
  .type  g1,@object
  .size  g1,4
g1:
  .word 0

# CHECK:      Disassembly of section .text:
# CHECK-NEXT: __start:
# CHECK-NEXT:  20000:   3c 08 00 02   lui    $8, 2
#                                                ^-- %hi(__start+4)
# CHECK-NEXT:  20004:   3c 09 00 03   lui    $9, 3
#                                                ^-- %hi(g1+8)
# CHECK-NEXT:  20008:   21 08 00 04   addi   $8, $8, 4
#                                                    ^-- %lo(__start+4)
# CHECK-NEXT:  2000c:   21 08 00 0c   addi   $8, $8, 12
#                                                    ^-- %lo(g1+8)
# CHECK-NEXT:  20010:   3c 08 00 04   lui    $8, 4
#                                                ^-- %hi(l1+0x10000-4)
# CHECK-NEXT:  20014:   3c 09 00 05   lui    $9, 5
#                                                ^-- %hi(l1+0x20000-4)
# CHECK-NEXT:  20018:   21 08 ff fc   addi   $8, $8, -4
#                                                    ^-- %lo(l1-4)

# CHECK: SYMBOL TABLE:
# CHECK: 0030000 l     O .data   00000004 l1
# CHECK: 0020000         .text   00000000 __start
# CHECK: 0030004 g     O .data   00000004 g1
