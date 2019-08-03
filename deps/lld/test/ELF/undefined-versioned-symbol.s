// REQUIRES: x86
// RUN: echo ".data; \
// RUN:       .quad \"basename\"; \
// RUN:       .quad \"basename@FBSD_1.0\"; \
// RUN:       .quad \"basename@FBSD_1.1\" " > %t.s
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %t.s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t2.o
// RUN: echo "FBSD_1.0 { local: *; }; FBSD_1.1 { };" > %t2.ver
// RUN: ld.lld --shared --version-script %t2.ver %t2.o -o %t2.so
// RUN: echo "LIBPKG_1.3 { };" > %t.ver
// RUN: ld.lld --shared %t.o --version-script %t.ver %t2.so -o %t.so
// RUN: llvm-readobj --dyn-symbols -r --expand-relocs %t.so | FileCheck %s

// Test that each relocation points to the correct version.

// CHECK:      Section ({{.*}}) .rela.dyn {
// CHECK-NEXT:   Relocation {
// CHECK-NEXT:     Offset: 0x2000
// CHECK-NEXT:     Type: R_X86_64_64 (1)
// CHECK-NEXT:     Symbol: basename@FBSD_1.1 (1)
// CHECK-NEXT:     Addend: 0x0
// CHECK-NEXT:   }
// CHECK-NEXT:   Relocation {
// CHECK-NEXT:     Offset: 0x2008
// CHECK-NEXT:     Type: R_X86_64_64 (1)
// CHECK-NEXT:     Symbol: basename@FBSD_1.0 (2)
// CHECK-NEXT:     Addend: 0x0
// CHECK-NEXT:   }
// CHECK-NEXT:   Relocation {
// CHECK-NEXT:     Offset: 0x2010
// CHECK-NEXT:     Type: R_X86_64_64 (1)
// CHECK-NEXT:     Symbol: basename@FBSD_1.1 (3)
// CHECK-NEXT:     Addend: 0x0
// CHECK-NEXT:   }
// CHECK-NEXT: }


// CHECK:      DynamicSymbols [
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name:
// CHECK-NEXT:     Value:
// CHECK-NEXT:     Size:
// CHECK-NEXT:     Binding:
// CHECK-NEXT:     Type:
// CHECK-NEXT:     Other:
// CHECK-NEXT:     Section:
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: basename@FBSD_1.1
// CHECK-NEXT:     Value:
// CHECK-NEXT:     Size:
// CHECK-NEXT:     Binding:
// CHECK-NEXT:     Type:
// CHECK-NEXT:     Other:
// CHECK-NEXT:     Section:
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: basename@FBSD_1.0
// CHECK-NEXT:     Value:
// CHECK-NEXT:     Size:
// CHECK-NEXT:     Binding:
// CHECK-NEXT:     Type:
// CHECK-NEXT:     Other:
// CHECK-NEXT:     Section:
// CHECK-NEXT:   }
// CHECK-NEXT:   Symbol {
// CHECK-NEXT:     Name: basename@FBSD_1.1


.global "basename@FBSD_1.0"
"basename@FBSD_1.0":

.global "basename@@FBSD_1.1"
"basename@@FBSD_1.1":
