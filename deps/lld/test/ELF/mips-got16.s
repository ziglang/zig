# REQUIRES: mips
# Check R_MIPS_GOT16 relocation calculation.

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux %s -o %t.o
# RUN: ld.lld %t.o -shared -o %t.so
# RUN: llvm-objdump -d -t %t.so | FileCheck %s
# RUN: llvm-readelf -r --mips-plt-got %t.so | FileCheck -check-prefix=GOT %s

# CHECK:      Disassembly of section .text:
# CHECK-EMPTY:
# CHECK-NEXT: __start:
# CHECK-NEXT:    10000:       8f 88 80 18     lw      $8, -32744($gp)
# CHECK-NEXT:    10004:       21 08 00 2c     addi    $8, $8, 44
# CHECK-NEXT:    10008:       8f 88 80 24     lw      $8, -32732($gp)
# CHECK-NEXT:    1000c:       21 08 90 00     addi    $8, $8, -28672
# CHECK-NEXT:    10010:       8f 88 80 28     lw      $8, -32728($gp)
# CHECK-NEXT:    10014:       21 08 90 04     addi    $8, $8, -28668
# CHECK-NEXT:    10018:       8f 88 80 28     lw      $8, -32728($gp)
# CHECK-NEXT:    1001c:       21 08 10 04     addi    $8, $8, 4100
# CHECK-NEXT:    10020:       8f 88 80 30     lw      $8, -32720($gp)
# CHECK-NEXT:    10024:       21 08 10 08     addi    $8, $8, 4104
# CHECK-NEXT:    10028:       8f 88 80 34     lw      $8, -32716($gp)
#
# CHECK: SYMBOL TABLE:
# CHECK: 00041008         .data           00000000 .hidden bar
# CHECK: 00000000         *UND*           00000000 foo

# GOT: There are no relocations in this file.

# GOT:       Local entries:
# GOT-NEXT:    Address     Access  Initial
# GOT-NEXT:   00041018 -32744(gp) 00010000
#                                 ^-- (0x1002c + 0x8000) & ~0xffff
# GOT-NEXT:   0004101c -32740(gp) 00020000
#                                 ^-- redundant unused entry
# GOT-NEXT:   00041020 -32736(gp) 00020000
#                                 ^-- redundant unused entry
# GOT-NEXT:   00041024 -32732(gp) 00030000
#                                 ^-- (0x29000 + 0x8000) & ~0xffff
# GOT-NEXT:   00041028 -32728(gp) 00040000
#                                 ^-- (0x29000 + 0x10004 + 0x8000) & ~0xffff
#                                 ^-- (0x29000 + 0x18004 + 0x8000) & ~0xffff
# GOT-NEXT:   0004102c -32724(gp) 00050000
#                                 ^-- redundant unused entry
# GOT-NEXT:   00041030 -32720(gp) 00041008
#                                 ^-- 'bar' address
# GOT-EMPTY:
# GOT-NEXT:  Global entries:
# GOT-NEXT:    Address     Access  Initial Sym.Val. Type    Ndx Name
# GOT-NEXT:   00041034 -32716(gp) 00000000 00000000 NOTYPE  UND foo

  .text
  .globl  __start
__start:
  lw      $t0,%got($LC0)($gp)
  addi    $t0,$t0,%lo($LC0)
  lw      $t0,%got($LC1)($gp)
  addi    $t0,$t0,%lo($LC1)
  lw      $t0,%got($LC1+0x10004)($gp)
  addi    $t0,$t0,%lo($LC1+0x10004)
  lw      $t0,%got($LC1+0x18004)($gp)
  addi    $t0,$t0,%lo($LC1+0x18004)
  lw      $t0,%got(bar)($gp)
  addi    $t0,$t0,%lo(bar)
  lw      $t0,%got(foo)($gp)
$LC0:
  nop

  .data
  .space 0x9000
$LC1:
  .word 0
  .space 0x18000
  .word 0
.global bar
.hidden bar
bar:
  .word 0
