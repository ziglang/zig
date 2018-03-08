// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=i686-pc-linux %s -o %t.o
// RUN: ld.lld --hash-style=sysv %t.o -o %t.so -shared
// RUN: llvm-readobj -s %t.so | FileCheck %s
// RUN: llvm-objdump -d %t.so | FileCheck --check-prefix=DISASM %s

movl $_GLOBAL_OFFSET_TABLE_, %eax

// CHECK:      Name: .got
// CHECK-NEXT: Type: SHT_PROGBITS
// CHECK-NEXT: Flags [
// CHECK-NEXT:   SHF_ALLOC
// CHECK-NEXT:   SHF_WRITE
// CHECK-NEXT: ]
// CHECK-NEXT: Address: 0x2030

// DISASM:      Disassembly of section .text:
// DISASM-NEXT: .text:
// DISASM-NEXT:    1000: {{.*}}         movl    $4144, %eax
//                                              0x2030 - 0x1000 = 4144
