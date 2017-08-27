// REQUIRES: aarch64
// RUN: llvm-mc -filetype=obj -triple=aarch64-none-freebsd %s -o %t.o
// RUN: ld.lld %t.o -o %t
// RUN: llvm-readobj -s --section-data  %t | FileCheck %s

// CHECK:      Name: .got
// CHECK-NEXT: Type: SHT_PROGBITS
// CHECK-NEXT:  Flags [
// CHECK-NEXT:    SHF_ALLOC
// CHECK-NEXT:    SHF_WRITE
// CHECK-NEXT:  ]
// CHECK-NEXT:  Address: 0x30000
// CHECK-NEXT:  Offset: 0x20000
// CHECK-NEXT:  Size: 8
// CHECK-NEXT:  Link: 0
// CHECK-NEXT:  Info: 0
// CHECK-NEXT:  AddressAlignment: 8
// CHECK-NEXT:  EntrySize: 0
// CHECK-NEXT:  SectionData (
// CHECK-NEXT:    0000: 00000000 00000000                    |........|
// CHECK-NEXT:  )

        .globl  _start
_start:
        adrp    x8, :got:foo
        ldr     x8, [x8, :got_lo12:foo]
        ldr     w0, [x8]
        ret

        .weak   foo
