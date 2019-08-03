# REQUIRES: mips
# Check number of got entries is adjusted for linker script-added space.

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux %s -o %t.o
# RUN: echo "SECTIONS { .data : { *(.data.1); . += 0x10000; *(.data.2) } }" > %t.script
# RUN: ld.lld %t.o -shared -o %t.so -T %t.script
# RUN: llvm-readobj --mips-plt-got --dynamic-table %t.so | FileCheck %s

# CHECK: 0x7000000A MIPS_LOCAL_GOTNO 4
#                                    ^-- 2 * header + 2 local entries
# CHECK:      Local entries [
# CHECK-NEXT:   Entry {
# CHECK-NEXT:     Address:
# CHECK-NEXT:     Access: -32744
# CHECK-NEXT:     Initial: 0x0
#                          ^-- loc1
# CHECK-NEXT:   }
# CHECK-NEXT:   Entry {
# CHECK-NEXT:     Address:
# CHECK-NEXT:     Access: -32740
# CHECK-NEXT:     Initial: 0x10000
#                          ^-- loc2
# CHECK-NEXT:   }
# CHECK-NEXT: ]

  .text
  .globl  foo
foo:
  lw      $t0, %got(loc1)($gp)
  addi    $t0, $t0, %lo(loc1)
  lw      $t0, %got(loc2)($gp)
  addi    $t0, $t0, %lo(loc2)

  .section .data.1,"aw",%progbits
loc1:
  .word 0

  .section .data.2,"aw",%progbits
loc2:
  .word 0
