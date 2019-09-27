// REQUIRES: x86

// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t1.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux \
// RUN:   %p/Inputs/start-lib-comdat.s -o %t2.o
// RUN: ld.lld -shared -o %t3 %t1.o --start-lib %t2.o --end-lib
// RUN: llvm-readobj --symbols %t3 | FileCheck %s
// RUN: ld.lld -shared -o %t3 --start-lib %t2.o --end-lib %t1.o
// RUN: llvm-readobj --symbols %t3 | FileCheck %s

// CHECK:      Name: zed
// CHECK-NEXT: Value:
// CHECK-NEXT: Size:
// CHECK-NEXT: Binding: Global
// CHECK-NEXT: Type:
// CHECK-NEXT: Other:
// CHECK-NEXT: Section: Undefined

        call bar@plt
// The other file also has a section in the zed comdat, but it defines the
// symbol zed. That means that we will have a lazy symbol zed, but when adding
// the actual file zed will be undefined.
        .section        .sec,"aG",@progbits,zed,comdat
