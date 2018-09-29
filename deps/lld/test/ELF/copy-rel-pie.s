// REQUIRES: x86
// RUN: llvm-mc %s -o %t.o -filetype=obj -triple=x86_64-pc-linux
// RUN: llvm-mc %p/Inputs/copy-rel-pie.s -o %t2.o -filetype=obj -triple=x86_64-pc-linux
// RUN: ld.lld %t2.o -o %t2.so -shared
// RUN: ld.lld --hash-style=sysv %t.o %t2.so -o %t.exe -pie
// RUN: llvm-readobj -s -r %t.exe | FileCheck %s
// RUN: llvm-objdump -d %t.exe | FileCheck --check-prefix=DISASM %s

.global _start
_start:
        .byte 0xe8
        .long bar - . -4
        .byte 0xe8
        .long foo - . -4

// CHECK:      Name: .plt
// CHECK-NEXT: Type: SHT_PROGBITS
// CHECK-NEXT: Flags [
// CHECK-NEXT:   SHF_ALLOC
// CHECK-NEXT:   SHF_EXECINSTR
// CHECK-NEXT: ]
// CHECK-NEXT: Address: 0x1010

// CHECK:      Name: .bss
// CHECK-NEXT: Type: SHT_NOBITS
// CHECK-NEXT: Flags [
// CHECK-NEXT:   SHF_ALLOC
// CHECK-NEXT:   SHF_WRITE
// CHECK-NEXT: ]
// CHECK-NEXT: Address: 0x4000

// CHECK:      Relocations [
// CHECK-NEXT:   Section (4) .rela.dyn {
// CHECK-NEXT:     0x4000 R_X86_64_COPY foo 0x0
// CHECK-NEXT:   }
// CHECK-NEXT:   Section (5) .rela.plt {
// CHECK-NEXT:     0x2018 R_X86_64_JUMP_SLOT bar 0x0
// CHECK-NEXT:   }
// CHECK-NEXT: ]

// (0x1010 + 0x10) - 0x1005 = 27
// 0x4000          - 0x100a = 12278

// DISASM:      Disassembly of section .text:
// DISASM-NEXT: _start:
// DISASM-NEXT:     1000:       e8 1b 00 00 00  callq   27
// DISASM-NEXT:     1005:       e8 f6 2f 00 00  callq   12278 <foo>
