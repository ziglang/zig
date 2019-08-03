# REQUIRES: mips
# Check R_MIPS_CALL_HI16 / R_MIPS_CALL_LO16 relocations calculation.

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux %s -o %t.o
# RUN: ld.lld %t.o -shared -o %t.so
# RUN: llvm-objdump -d %t.so | FileCheck %s
# RUN: llvm-readelf -r --mips-plt-got %t.so | FileCheck -check-prefix=GOT %s

# CHECK:      Disassembly of section .text:
# CHECK-EMPTY:
# CHECK-NEXT: foo:
# CHECK-NEXT:    10000:       3c 02 00 00     lui     $2, 0
# CHECK-NEXT:    10004:       8c 42 80 20     lw      $2, -32736($2)
# CHECK-NEXT:    10008:       3c 02 00 00     lui     $2, 0
# CHECK-NEXT:    1000c:       8c 42 80 18     lw      $2, -32744($2)
# CHECK-NEXT:    10010:       3c 02 00 00     lui     $2, 0
# CHECK-NEXT:    10014:       8c 42 80 1c     lw      $2, -32740($2)

# GOT:      There are no relocations in this file.
# GOT:      Primary GOT:
# GOT-NEXT:  Canonical gp value: 00027ff0
# GOT-EMPTY:
# GOT-NEXT:  Reserved entries:
# GOT-NEXT:    Address     Access  Initial Purpose
# GOT-NEXT:   00020000 -32752(gp) 00000000 Lazy resolver
# GOT-NEXT:   00020004 -32748(gp) 80000000 Module pointer (GNU extension)
# GOT-EMPTY:
# GOT-NEXT:  Local entries:
# GOT-NEXT:    Address     Access  Initial
# GOT-NEXT:   00020008 -32744(gp) 00010018
# GOT-NEXT:   0002000c -32740(gp) 0001001c
# GOT-EMPTY:
# GOT-NEXT:  Global entries:
# GOT-NEXT:    Address     Access  Initial Sym.Val. Type    Ndx Name
# GOT-NEXT:   00020010 -32736(gp) 00000000 00000000 NOTYPE  UND bar

  .text
  .global foo
foo:
  lui   $2, %call_hi(bar)
  lw    $2, %call_lo(bar)($2)
  lui   $2, %call_hi(loc1)
  lw    $2, %call_lo(loc1)($2)
  lui   $2, %call_hi(loc2)
  lw    $2, %call_lo(loc2)($2)
loc1:
  nop
loc2:
  nop
