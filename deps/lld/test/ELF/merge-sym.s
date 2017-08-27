// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: ld.lld %t.o -o %t.so -shared
// RUN: llvm-readobj -t -s %t.so | FileCheck %s

        .section        .rodata.cst4,"aM",@progbits,4
        .short 0
foo:
        .short 42


// CHECK:      Name: .rodata
// CHECK-NEXT: Type: SHT_PROGBITS
// CHECK-NEXT: Flags [
// CHECK-NEXT:   SHF_ALLOC
// CHECK-NEXT:   SHF_MERGE
// CHECK-NEXT: ]
// CHECK-NEXT: Address: 0x1C8

// CHECK:      Name: foo
// CHECK-NEXT: Value: 0x1CA
