# Check calculation of MIPS GOT page address entries number
# when a linker script is provided.

# RUN: llvm-mc -filetype=obj -triple=mips64-unknown-linux -o %t.o %s
# RUN: echo "SECTIONS { \
# RUN:          .text : { *(.text) } \
# RUN:          .data 0x10000 : { *(.data) } }" > %t.script
# RUN: ld.lld -shared --script %t.script -o %t.so %t.o
# RUN: llvm-readobj -t -mips-plt-got %t.so | FileCheck %s

# REQUIRES: mips

# CHECK:      Name: foo1
# CHECK-NEXT: Value: 0x10000
# CHECK:      Name: foo2
# CHECK-NEXT: Value: 0x20000
# CHECK:      Name: foo3
# CHECK-NEXT: Value: 0x30000
# CHECK:      Name: foo4
# CHECK-NEXT: Value: 0x40000

# CHECK:      Local entries [
# CHECK-BEXT:    Entry {
# CHECK-BEXT:      Address:
# CHECK-BEXT:      Access:
# CHECK-BEXT:      Initial: 0x10000
# CHECK-BEXT:    }
# CHECK-BEXT:    Entry {
# CHECK-BEXT:      Address:
# CHECK-BEXT:      Access:
# CHECK-BEXT:      Initial: 0x20000
# CHECK-BEXT:    }
# CHECK-BEXT:    Entry {
# CHECK-BEXT:      Address:
# CHECK-BEXT:      Access:
# CHECK-BEXT:      Initial: 0x30000
# CHECK-BEXT:    }
# CHECK-BEXT:    Entry {
# CHECK-BEXT:      Address:
# CHECK-BEXT:      Access:
# CHECK-BEXT:      Initial: 0x40000
# CHECK-BEXT:    }
# CHECK-BEXT:    Entry {
# CHECK-BEXT:      Address:
# CHECK-BEXT:      Access:
# CHECK-BEXT:      Initial: 0x50000
# CHECK-BEXT:    }
# CHECK-BEXT:  ]

  .option pic2
  .text
  ld      $v0,%got_page(foo1)($gp)
  ld      $v0,%got_page(foo2)($gp)
  ld      $v0,%got_page(foo3)($gp)
  ld      $v0,%got_page(foo4)($gp)

  .data
foo1:
  .space 0x10000
foo2:
  .space 0x10000
foo3:
  .space 0x10000
foo4:
  .word 0
