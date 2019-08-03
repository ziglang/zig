// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
// RUN: ld.lld --hash-style=sysv %t.o -o %t -pie
// RUN: llvm-readobj -S -r -d %t | FileCheck %s
// RUN: llvm-objdump -d %t | FileCheck --check-prefix=DISASM %s

.globl _start
_start:
 call foo@gotpcrel

 .hidden foo
 .global foo
foo:
 nop

// 0x20B0 - 1001 - 5 = 4266
// DISASM:      Disassembly of section .text:
// DISASM-EMPTY:
// DISASM-NEXT: _start:
// DISASM-NEXT:   1000: {{.*}} callq 4267
// DISASM:      foo:
// DISASM-NEXT:   1005: {{.*}} nop

// CHECK:      Name: .got
// CHECK-NEXT: Type: SHT_PROGBITS
// CHECK-NEXT: Flags [
// CHECK-NEXT:   SHF_ALLOC
// CHECK-NEXT:   SHF_WRITE
// CHECK-NEXT: ]
// CHECK-NEXT: Address: 0x20B0
// CHECK-NEXT: Offset:
// CHECK-NEXT: Size: 8

// CHECK:      Relocations [
// CHECK-NEXT:   Section ({{.*}}) .rela.dyn {
// CHECK-NEXT:     0x20B0 R_X86_64_RELATIVE - 0x1005
// CHECK-NEXT:   }
// CHECK-NEXT: ]
// CHECK:      0x000000006FFFFFF9 RELACOUNT            1
