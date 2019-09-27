// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
// RUN: ld.lld %t -o %tout
// RUN: llvm-readobj -S %tout | FileCheck %s
// RUN: echo "SECTIONS { \
// RUN:   . = 0x201000; \
// RUN:   .text : { *(.text) } \
// RUN:   . = 0x202000; \
// RUN:   .tdata : { *(.tdata) } \
// RUN:   .tbss : { *(.tbss) } \
// RUN:   .data.rel.ro : { *(.data.rel.ro) } \
// RUN: }" > %t.script
// RUN: ld.lld -T %t.script %t -o %tout2
// RUN: echo SCRIPT
// RUN: llvm-readobj -S %tout2 | FileCheck %s
        .global _start
_start:
        retq

        .section        .tdata,"awT",@progbits
        .align  4
        .long   42

        .section        .tbss,"awT",@nobits
        .align  16
        .zero 16

        .section        .data.rel.ro,"aw",@progbits
        .long 1


// Test that .tbss doesn't show up in the offset or in the address. If this
// gets out of sync what we get a runtime is different from what the section
// table says.

// CHECK:      Name: .tdata
// CHECK-NEXT: Type: SHT_PROGBITS
// CHECK-NEXT: Flags [
// CHECK-NEXT:   SHF_ALLOC
// CHECK-NEXT:   SHF_TLS
// CHECK-NEXT:   SHF_WRITE
// CHECK-NEXT: ]
// CHECK-NEXT: Address: 0x202000
// CHECK-NEXT: Offset: 0x2000
// CHECK-NEXT: Size: 4

// CHECK:      Name: .tbss
// CHECK-NEXT: Type: SHT_NOBITS
// CHECK-NEXT: Flags [
// CHECK-NEXT:   SHF_ALLOC
// CHECK-NEXT:   SHF_TLS
// CHECK-NEXT:   SHF_WRITE
// CHECK-NEXT: ]
// CHECK-NEXT: Address: 0x202010
// CHECK-NEXT: Offset: 0x2004
// CHECK-NEXT: Size: 16

// CHECK:      Name: .data.rel.ro
// CHECK-NEXT: Type: SHT_PROGBITS
// CHECK-NEXT: Flags [
// CHECK-NEXT:   SHF_ALLOC
// CHECK-NEXT:   SHF_WRITE
// CHECK-NEXT: ]
// CHECK-NEXT: Address: 0x202004
// CHECK-NEXT: Offset: 0x2004
// CHECK-NEXT: Size: 4
