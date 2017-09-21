# Check R_MIPS_GOT16 relocation calculation.

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux %s -o %t.o
# RUN: ld.lld %t.o -shared -o %t.so
# RUN: llvm-objdump -d -t %t.so | FileCheck %s
# RUN: llvm-readobj -r -mips-plt-got %t.so | FileCheck -check-prefix=GOT %s

# REQUIRES: mips

# CHECK:      Disassembly of section .text:
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

# GOT:      Relocations [
# GOT-NEXT: ]

# GOT:      Primary GOT {
# GOT-NEXT:   Canonical gp value:
# GOT-NEXT:   Reserved entries [
# GOT-NEXT:     Entry {
# GOT-NEXT:       Address:
# GOT-NEXT:       Access: -32752
# GOT-NEXT:       Initial: 0x0
# GOT-NEXT:       Purpose: Lazy resolver
# GOT-NEXT:     }
# GOT-NEXT:     Entry {
# GOT-NEXT:       Address:
# GOT-NEXT:       Access: -32748
# GOT-NEXT:       Initial: 0x80000000
# GOT-NEXT:       Purpose: Module pointer (GNU extension)
# GOT-NEXT:     }
# GOT-NEXT:   ]
# GOT-NEXT:   Local entries [
# GOT-NEXT:     Entry {
# GOT-NEXT:       Address:
# GOT-NEXT:       Access: -32744
# GOT-NEXT:       Initial: 0x10000
#                          ^-- (0x1002c + 0x8000) & ~0xffff
# GOT-NEXT:     }
# GOT-NEXT:     Entry {
# GOT-NEXT:       Address:
# GOT-NEXT:       Access: -32740
# GOT-NEXT:       Initial: 0x20000
#                          ^-- redundant unused entry
# GOT-NEXT:     }
# GOT-NEXT:     Entry {
# GOT-NEXT:       Address:
# GOT-NEXT:       Access: -32736
# GOT-NEXT:       Initial: 0x20000
#                          ^-- redundant unused entry
# GOT-NEXT:     }
# GOT-NEXT:     Entry {
# GOT-NEXT:       Address:
# GOT-NEXT:       Access: -32732
# GOT-NEXT:       Initial: 0x30000
#                          ^-- (0x29000 + 0x8000) & ~0xffff
# GOT-NEXT:     }
# GOT-NEXT:     Entry {
# GOT-NEXT:       Address:
# GOT-NEXT:       Access: -32728
# GOT-NEXT:       Initial: 0x40000
#                          ^-- (0x29000 + 0x10004 + 0x8000) & ~0xffff
#                          ^-- (0x29000 + 0x18004 + 0x8000) & ~0xffff
# GOT-NEXT:     }
# GOT-NEXT:     Entry {
# GOT-NEXT:       Address:
# GOT-NEXT:       Access: -32724
# GOT-NEXT:       Initial: 0x50000
#                          ^-- redundant unused entry
# GOT-NEXT:     }
# GOT-NEXT:     Entry {
# GOT-NEXT:       Address:
# GOT-NEXT:       Access: -32720
# GOT-NEXT:       Initial: 0x41008
#                          ^-- 'bar' address
# GOT-NEXT:     }
# GOT-NEXT:   ]
# GOT-NEXT:   Global entries [
# GOT-NEXT:     Entry {
# GOT-NEXT:       Address:
# GOT-NEXT:       Access: -32716
# GOT-NEXT:       Initial: 0x0
# GOT-NEXT:       Value: 0x0
# GOT-NEXT:       Type: None
# GOT-NEXT:       Section: Undefined
# GOT-NEXT:       Name: foo@
# GOT-NEXT:     }
# GOT-NEXT:   ]
# GOT-NEXT:   Number of TLS and multi-GOT entries: 0
# GOT-NEXT: }

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
