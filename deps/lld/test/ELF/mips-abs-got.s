# REQUIRES: mips

# Check GOT relocations against absolute symbols.

# RUN: llvm-mc -filetype=obj -triple=mips64-unknown-linux -o %t.o %s
# RUN: echo "SECTIONS { \
# RUN:          zero1 = 0; zero2 = 0; foo = 0x11004; bar = 0x22000; }" > %t.script
# RUN: ld.lld --script %t.script -o %t.exe %t.o
# RUN: llvm-readobj --mips-plt-got %t.exe | FileCheck %s

# CHECK:      Static GOT {
# CHECK:        Local entries [
# CHECK-NEXT:     Entry {
# CHECK-NEXT:       Address:
# CHECK-NEXT:       Access: -32736
# CHECK-NEXT:       Initial: 0x0
# CHECK-NEXT:     }
# CHECK-NEXT:     Entry {
# CHECK-NEXT:       Address:
# CHECK-NEXT:       Access: -32728
# CHECK-NEXT:       Initial: 0x10000
# CHECK-NEXT:     }
# CHECK-NEXT:     Entry {
# CHECK-NEXT:       Address:
# CHECK-NEXT:       Access: -32720
# CHECK-NEXT:       Initial: 0x30000
# CHECK-NEXT:     }
# CHECK-NEXT:   ]
# CHECK-NEXT: }

  .text
  nop
  ld      $v0, %got_page(zero1)($gp)
  ld      $v0, %got_page(zero2)($gp)
  ld      $v0, %got_page(foo)($gp)
  ld      $v0, %got_page(bar+0x10008)($gp)
