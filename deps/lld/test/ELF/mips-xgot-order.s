# REQUIRES: mips
# Check that GOT entries accessed via 16-bit indexing are allocated
# in the beginning of the GOT.

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux %s -o %t.o
# RUN: ld.lld %t.o -o %t.exe
# RUN: llvm-objdump -d -s -t %t.exe | FileCheck %s

# CHECK:      Disassembly of section .text:
# CHECK-NEXT: __start:
# CHECK-NEXT:    20000:       3c 02 00 00     lui     $2, 0
# CHECK-NEXT:    20004:       8c 42 80 24     lw      $2, -32732($2)
# CHECK-NEXT:    20008:       3c 02 00 00     lui     $2, 0
# CHECK-NEXT:    2000c:       8c 42 80 28     lw      $2, -32728($2)
#
# CHECK:      bar:
# CHECK-NEXT:    20010:       8c 42 80 20     lw      $2, -32736($2)
# CHECK-NEXT:    20014:       8c 42 80 18     lw      $2, -32744($2)
# CHECK-NEXT:    20018:       20 42 00 00     addi    $2, $2, 0

# CHECK:      Contents of section .got:
# CHECK-NEXT:  30010 00000000 80000000 00030000 00040000
#                                      ^ %hi(loc)
#                                               ^ redundant entry
# CHECK-NEXT:  30020 00020010 00020000 00030000
#                    ^ %got(bar)
#                             ^ %got_hi/lo(start)
#                                      ^ %got_hi/lo(loc)

# CHECK: 00030000         .data           00000000 loc
# CHECK: 00020000         .text           00000000 __start
# CHECK: 00020010         .text           00000000 bar

  .text
  .global __start, bar
__start:
  lui   $2, %got_hi(__start)
  lw    $2, %got_lo(__start)($2)
  lui   $2, %got_hi(loc)
  lw    $2, %got_lo(loc)($2)
bar:
  lw    $2, %got(bar)($2)
  lw    $2, %got(loc)($2)
  addi  $2, $2, %lo(loc)

  .data
loc:
  .word 0
