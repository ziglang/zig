// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=i686-unknown-linux %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=i686-unknown-linux %p/Inputs/undef-with-plt-addr.s -o %t2.o
// RUN: ld.lld %t2.o -o %t2.so -shared
// RUN: ld.lld %t.o %t2.so -o %t3
// RUN: llvm-readobj -t -s %t3 | FileCheck %s

.globl _start
_start:
mov $set_data, %eax

// Test that set_data has an address in the .plt

// CHECK:      Name: .plt
// CHECK-NEXT: Type: SHT_PROGBITS
// CHECK-NEXT: Flags [
// CHECK-NEXT:   SHF_ALLOC
// CHECK-NEXT:   SHF_EXECINSTR
// CHECK-NEXT: ]
// CHECK-NEXT: Address: 0x401010

// CHECK:      Name:    set_data
// CHECK-NEXT: Value:   0x401020
