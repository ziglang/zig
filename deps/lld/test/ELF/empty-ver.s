// REQUIRES: x86
// RUN: mkdir -p %t.dir
// RUN: cd %t.dir
// RUN: llvm-mc %s -o %t.o -filetype=obj -triple=x86_64-pc-linux
// RUN: ld.lld %t.o -o t.so -shared -version-script %p/Inputs/empty-ver.ver
// RUN: llvm-readobj -S --section-data --version-info t.so | FileCheck %s

// CHECK:      Name: .dynstr
// CHECK-NEXT: Type: SHT_STRTAB
// CHECK-NEXT: Flags [
// CHECK-NEXT:   SHF_ALLOC
// CHECK-NEXT: ]
// CHECK-NEXT: Address:
// CHECK-NEXT: Offset:
// CHECK-NEXT: Size: 14
// CHECK-NEXT: Link: 0
// CHECK-NEXT: Info: 0
// CHECK-NEXT: AddressAlignment: 1
// CHECK-NEXT: EntrySize: 0
// CHECK-NEXT: SectionData (
// CHECK-NEXT:   0000: 00666F6F 00742E73 6F007665 7200      |.foo.t.so.ver.|
// CHECK-NEXT: )

// CHECK:      Version symbols {
// CHECK-NEXT:   Section Name:
// CHECK-NEXT:   Address:
// CHECK-NEXT:   Offset:
// CHECK-NEXT:   Link:
// CHECK-NEXT:   Symbols [
// CHECK-NEXT:     Symbol {
// CHECK-NEXT:       Version: 0
// CHECK-NEXT:       Name:
// CHECK-NEXT:     }
// CHECK-NEXT:     Symbol {
// CHECK-NEXT:       Version: 2
// CHECK-NEXT:       Name: foo@ver
// CHECK-NEXT:     }
// CHECK-NEXT:   ]
// CHECK-NEXT: }


.global foo@ver
foo@ver:
