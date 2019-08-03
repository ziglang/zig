// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t1.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/tls-got.s -o %t2.o
// RUN: ld.lld -shared %t2.o -o %t2.so
// RUN: ld.lld --hash-style=sysv -e main %t1.o %t2.so -o %t3
// RUN: llvm-readobj -S -r %t3 | FileCheck %s
// RUN: llvm-objdump -d %t3 | FileCheck --check-prefix=DISASM %s

// CHECK:      Section {
// CHECK:      Index: 8
// CHECK-NEXT: Name: .got
// CHECK-NEXT: Type: SHT_PROGBITS
// CHECK-NEXT: Flags [
// CHECK-NEXT:   SHF_ALLOC
// CHECK-NEXT:   SHF_WRITE
// CHECK-NEXT: ]
// CHECK-NEXT: Address: [[ADDR:.*]]
// CHECK-NEXT: Offset: 0x20C0
// CHECK-NEXT: Size: 16
// CHECK-NEXT: Link: 0
// CHECK-NEXT: Info: 0
// CHECK-NEXT: AddressAlignment: 8
// CHECK-NEXT: EntrySize: 0
// CHECK-NEXT: }

// CHECK:      Relocations [
// CHECK-NEXT:   Section (4) .rela.dyn {
// CHECK-NEXT:     0x2020C8 R_X86_64_TPOFF64 tls0 0x0
// CHECK-NEXT:     [[ADDR]] R_X86_64_TPOFF64 tls1 0x0
// CHECK-NEXT:   }
// CHECK-NEXT: ]

// 0x201000 + 4281 + 7 = 0x2020C0
// 0x20100A + 4279 + 7 = 0x2020C8
// 0x201014 + 4269 + 7 = 0x2020C8
// DISASM:      Disassembly of section .text:
// DISASM-EMPTY:
// DISASM-NEXT: main:
// DISASM-NEXT: 201000: {{.*}} movq 4281(%rip), %rax
// DISASM-NEXT: 201007: {{.*}} movl %fs:(%rax), %eax
// DISASM-NEXT: 20100a: {{.*}} movq 4279(%rip), %rax
// DISASM-NEXT: 201011: {{.*}} movl %fs:(%rax), %eax
// DISASM-NEXT: 201014: {{.*}} movq 4269(%rip), %rax
// DISASM-NEXT: 20101b: {{.*}} movl %fs:(%rax), %eax
// DISASM-NEXT: 20101e: {{.*}} retq

.section .tdata,"awT",@progbits

.text
 .globl main
 .align 16, 0x90
 .type main,@function
main:
 movq tls1@GOTTPOFF(%rip), %rax
 movl %fs:0(%rax), %eax
 movq tls0@GOTTPOFF(%rip), %rax
 movl %fs:0(%rax), %eax
 movq tls0@GOTTPOFF(%rip), %rax
 movl %fs:0(%rax), %eax
 ret
