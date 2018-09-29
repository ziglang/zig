// REQUIRES: aarch64
// RUN: llvm-mc -filetype=obj -triple=aarch64-pc-freebsd %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=aarch64-pc-freebsd %p/Inputs/relocation-copy.s -o %t2.o
// RUN: ld.lld -shared %t2.o -soname fixed-length-string.so -o %t2.so
// RUN: ld.lld %t.o %t2.so -o %t3
// RUN: llvm-readobj -s -r --expand-relocs -symbols %t3 | FileCheck %s
// RUN: llvm-objdump -d %t3 | FileCheck -check-prefix=CODE %s
// RUN: llvm-objdump -s -section=.rodata %t3 | FileCheck -check-prefix=RODATA %s

.text
.globl _start
_start:
    adr x1, x
    adrp x2, y
    add x2, x2, :lo12:y
.rodata
    .word z

// CHECK:     Name: .bss
// CHECK-NEXT:     Type: SHT_NOBITS
// CHECK-NEXT:     Flags [
// CHECK-NEXT:       SHF_ALLOC
// CHECK-NEXT:       SHF_WRITE
// CHECK-NEXT:     ]
// CHECK-NEXT:     Address: 0x40000
// CHECK-NEXT:     Offset:
// CHECK-NEXT:     Size: 24
// CHECK-NEXT:     Link:
// CHECK-NEXT:     Info:
// CHECK-NEXT:     AddressAlignment: 16

// CHECK: Relocations [
// CHECK-NEXT:   Section ({{.*}}) .rela.dyn {
// CHECK-NEXT:     Relocation {
// CHECK-NEXT:       Offset: 0x40000
// CHECK-NEXT:       Type: R_AARCH64_COPY
// CHECK-NEXT:       Symbol: x
// CHECK-NEXT:       Addend: 0x0
// CHECK-NEXT:     }
// CHECK-NEXT:     Relocation {
// CHECK-NEXT:       Offset: 0x40010
// CHECK-NEXT:       Type: R_AARCH64_COPY
// CHECK-NEXT:       Symbol: y
// CHECK-NEXT:       Addend: 0x0
// CHECK-NEXT:     }
// CHECK-NEXT:     Relocation {
// CHECK-NEXT:       Offset: 0x40014
// CHECK-NEXT:       Type: R_AARCH64_COPY
// CHECK-NEXT:       Symbol: z
// CHECK-NEXT:       Addend: 0x0
// CHECK-NEXT:     }
// CHECK-NEXT:   }
// CHECK-NEXT: ]

// CHECK: Symbols [
// CHECK:     Name: x
// CHECK-NEXT:     Value: 0x40000
// CHECK-NEXT:     Size: 4
// CHECK-NEXT:     Binding: Global
// CHECK-NEXT:     Type: Object
// CHECK-NEXT:     Other:
// CHECK-NEXT:     Section: .bss
// CHECK:     Name: y
// CHECK-NEXT:     Value: 0x40010
// CHECK-NEXT:     Size: 4
// CHECK-NEXT:     Binding: Global
// CHECK-NEXT:     Type: Object
// CHECK-NEXT:     Other:
// CHECK-NEXT:     Section: .bss
// CHECK:     Name: z
// CHECK-NEXT:     Value: 0x40014
// CHECK-NEXT:     Size: 4
// CHECK-NEXT:     Binding: Global
// CHECK-NEXT:     Type: Object
// CHECK-NEXT:     Other:
// CHECK-NEXT:     Section: .bss
// CHECK: ]

// CODE: Disassembly of section .text:
// CODE-NEXT: _start:
// S(x) = 0x40000, A = 0, P = 0x20000
// S + A - P = 0x20000 = 131072
// CODE-NEXT:  20000: {{.*}} adr  x1, #131072
// S(y) = 0x40010, A = 0, P = 0x20004
// Page(S + A) - Page(P) = 0x40000 - 0x20000 = 0x20000 = 131072
// CODE-NEXT:  20004: {{.*}} adrp x2, #131072
// S(y) = 0x40010, A = 0
// (S + A) & 0xFFF = 0x10 = 16
// CODE-NEXT:  20008: {{.*}} add  x2, x2, #16

// RODATA: Contents of section .rodata:
// S(z) = 0x40014
// RODATA-NEXT:  102e0 14000400
