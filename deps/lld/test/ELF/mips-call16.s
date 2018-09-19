# REQUIRES: mips
# Check R_MIPS_CALL16 relocation calculation.

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux %s -o %t.o
# RUN: ld.lld %t.o -shared -o %t.exe
# RUN: llvm-objdump -d %t.exe | FileCheck %s
# RUN: llvm-readobj -mips-plt-got -symbols %t.exe \
# RUN:   | FileCheck -check-prefix=GOT %s

  .text
  .globl  __start
__start:
  lw      $t0,%call16(g1)($gp)

  .globl g1
  .type  g1,@function
g1:
  nop

# CHECK:      Disassembly of section .text:
# CHECK-NEXT: __start:
# CHECK-NEXT:      10000:   8f 88 80 18   lw   $8, -32744

# GOT:      Name: g1
# GOT-NEXT: Value: 0x[[ADDR:[0-9A-F]+]]

# GOT:      Local entries [
# GOT-NEXT: ]
# GOT-NEXT: Global entries [
# GOT-NEXT:   Entry {
# GOT-NEXT:     Address:
# GOT-NEXT:     Access: -32744
# GOT-NEXT:     Initial: 0x[[ADDR]]
# GOT-NEXT:     Value: 0x[[ADDR]]
# GOT-NEXT:     Type: Function
# GOT-NEXT:     Section: .text
# GOT-NEXT:     Name: g1
# GOT-NEXT:   }
# GOT-NEXT: ]
