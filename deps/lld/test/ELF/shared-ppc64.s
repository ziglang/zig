// REQUIRES: ppc

// RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %p/Inputs/shared.s -o %t2.o
// RUN: ld.lld -shared %t2.o -o %t2.so
// RUN: ld.lld -dynamic-linker /lib64/ld64.so.1 -rpath foo -rpath bar --export-dynamic %t.o %t2.so -o %t
// RUN: llvm-readobj --dynamic-table -s %t | FileCheck %s

// RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %p/Inputs/shared.s -o %t2.o
// RUN: ld.lld -shared %t2.o -o %t2.so
// RUN: ld.lld -dynamic-linker /lib64/ld64.so.1 -rpath foo -rpath bar --export-dynamic %t.o %t2.so -o %t
// RUN: llvm-readobj --dynamic-table -s %t | FileCheck %s

// CHECK:      Name: .rela.dyn
// CHECK-NEXT: Type: SHT_REL
// CHECK-NEXT: Flags [
// CHECK-NEXT:   SHF_ALLOC
// CHECK-NEXT: ]
// CHECK-NEXT: Address: [[RELADDR:.*]]
// CHECK-NEXT: Offset:
// CHECK-NEXT: Size: [[RELSIZE:.*]]
// CHECK-NEXT: Link:
// CHECK-NEXT: Info:
// CHECK-NEXT: AddressAlignment:
// CHECK-NEXT: EntrySize: [[RELENT:.*]]

// CHECK:      DynamicSection [
// CHECK-NEXT:   Tag                Type                 Name/Value
// CHECK-NEXT:   0x000000000000001D RUNPATH              foo:bar
// CHECK-NEXT:   0x0000000000000001 NEEDED               Shared library: [{{.*}}2.so]
// CHECK-NEXT:   0x0000000000000015 DEBUG                0x0
// CHECK-NEXT:   0x0000000000000007 RELA                 [[RELADDR]]
// CHECK-NEXT:   0x0000000000000008 RELASZ               [[RELSIZE]] (bytes)
// CHECK-NEXT:   0x0000000000000009 RELAENT              [[RELENT]] (bytes)
// CHECK:        0x0000000000000000 NULL                 0x0
// CHECK-NEXT: ]

.global _start
_start:
.data
.long bar
.long zed

