# Check microMIPS GOT relocations for N64 ABI.

# RUN: llvm-mc -filetype=obj -triple=mips64-unknown-linux -mattr=micromips \
# RUN:         %s -o %t1.o
# RUN: llvm-mc -filetype=obj -triple=mips64-unknown-linux -mattr=micromips \
# RUN:         %S/Inputs/mips-dynamic.s -o %t2.o
# RUN: ld.lld %t2.o -shared -o %t.so
# RUN: ld.lld %t1.o %t.so -o %t.exe
# RUN: llvm-readobj -mips-plt-got %t.exe | FileCheck %s

# REQUIRES: mips

# CHECK:      Local entries [
# CHECK-NEXT:   Entry {
# CHECK-NEXT:     Address:
# CHECK-NEXT:     Access: -32736
# CHECK-NEXT:     Initial: 0x30000
# CHECK-NEXT:   }
# CHECK-NEXT:   Entry {
# CHECK-NEXT:     Address:
# CHECK-NEXT:     Access: -32728
# CHECK-NEXT:     Initial: 0x40000
# CHECK-NEXT:   }
# CHECK-NEXT: ]
# CHECK-NEXT: Global entries [
# CHECK-NEXT:   Entry {
# CHECK-NEXT:     Address:
# CHECK-NEXT:     Access: -32720
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
  lui     $28, %hi(%neg(%gp_rel(foo0)))
  addiu   $28, $28, %lo(%neg(%gp_rel(foo0)))
  lw       $4, %got_page(data)($28)
  addiu    $4, $4, %got_ofst(data)
  lw      $25, %call16(foo0)($28)

  .data
data:
  .word 0
