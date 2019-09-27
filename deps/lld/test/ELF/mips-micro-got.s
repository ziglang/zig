# REQUIRES: mips
# Check microMIPS GOT relocations for O32 ABI.

# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux -mattr=micromips \
# RUN:         %s -o %t1.o
# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux -mattr=micromips \
# RUN:         %S/Inputs/mips-dynamic.s -o %t2.o
# RUN: ld.lld %t2.o -shared -o %t.so
# RUN: ld.lld %t1.o %t.so -o %t.exe
# RUN: llvm-readobj --mips-plt-got %t.exe | FileCheck %s

# CHECK:      Local entries [
# CHECK-NEXT:   Entry {
# CHECK-NEXT:     Address:
# CHECK-NEXT:     Access: -32744
# CHECK-NEXT:     Initial: 0x30000
# CHECK-NEXT:   }
# CHECK-NEXT:   Entry {
# CHECK-NEXT:     Address:
# CHECK-NEXT:     Access: -32740
# CHECK-NEXT:     Initial: 0x40000
# CHECK-NEXT:   }
# CHECK-NEXT: ]
# CHECK-NEXT: Global entries [
# CHECK-NEXT:   Entry {
# CHECK-NEXT:     Address:
# CHECK-NEXT:     Access: -32736
# CHECK-NEXT:     Initial: 0x0
# CHECK-NEXT:     Value: 0x0
# CHECK-NEXT:     Type: Function
# CHECK-NEXT:     Section: Undefined
# CHECK-NEXT:     Name: foo0
# CHECK-NEXT:   }
# CHECK-NEXT: ]

  .text
  .global __start
__start:
  lw       $4, %got(data)($28)
  addiu    $4, $4, %lo(data)
  lw      $25, %call16(foo0)($28)

  .data
data:
  .word 0
