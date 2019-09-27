# REQUIRES: mips
# Check R_MIPS_GOT_HI16 / R_MIPS_GOT_LO16 relocations calculation.

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux %s -o %t.o
# RUN: ld.lld %t.o -shared -o %t.so
# RUN: llvm-objdump -d %t.so | FileCheck %s
# RUN: llvm-readobj -r --mips-plt-got %t.so | FileCheck -check-prefix=GOT %s

# CHECK:      Disassembly of section .text:
# CHECK-EMPTY:
# CHECK-NEXT: foo:
# CHECK-NEXT:    10000:       3c 02 00 00     lui     $2, 0
# CHECK-NEXT:    10004:       8c 42 80 20     lw      $2, -32736($2)
# CHECK-NEXT:    10008:       3c 02 00 00     lui     $2, 0
# CHECK-NEXT:    1000c:       8c 42 80 18     lw      $2, -32744($2)
# CHECK-NEXT:    10010:       3c 02 00 00     lui     $2, 0
# CHECK-NEXT:    10014:       8c 42 80 1c     lw      $2, -32740($2)

# GOT:      Relocations [
# GOT-NEXT: ]

# GOT:      Primary GOT {
# GOT-NEXT:   Canonical gp value:
# GOT:        Local entries [
# GOT-NEXT:     Entry {
# GOT-NEXT:       Address:
# GOT-NEXT:       Access: -32744
# GOT-NEXT:       Initial: 0x20000
# GOT-NEXT:     }
# GOT-NEXT:     Entry {
# GOT-NEXT:       Address:
# GOT-NEXT:       Access: -32740
# GOT-NEXT:       Initial: 0x20004
# GOT-NEXT:     }
# GOT-NEXT:   ]
# GOT-NEXT:   Global entries [
# GOT-NEXT:     Entry {
# GOT-NEXT:       Address:
# GOT-NEXT:       Access: -32736
# GOT-NEXT:       Initial: 0x0
# GOT-NEXT:       Value: 0x0
# GOT-NEXT:       Type: None
# GOT-NEXT:       Section: Undefined
# GOT-NEXT:       Name: bar
# GOT-NEXT:     }
# GOT-NEXT:   ]
# GOT-NEXT:   Number of TLS and multi-GOT entries: 0
# GOT-NEXT: }

  .text
  .global foo
foo:
  lui   $2, %got_hi(bar)
  lw    $2, %got_lo(bar)($2)
  lui   $2, %got_hi(loc1)
  lw    $2, %got_lo(loc1)($2)
  lui   $2, %got_hi(loc2)
  lw    $2, %got_lo(loc2)($2)

  .data
loc1:
  .word 0
loc2:
  .word 0
