// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
// RUN: ld.lld %t.o -o %t1
// RUN: llvm-readobj -r %t1 | FileCheck --check-prefix=NORELOC %s
// RUN: llvm-objdump -d %t1 | FileCheck --check-prefix=DISASM %s

// NORELOC:      Relocations [
// NORELOC-NEXT: ]

// DISASM:      Disassembly of section .text:
// DISASM-NEXT: _start:
// DISASM-NEXT: 201000: 48 c7 c0 f8 ff ff ff movq $-8, %rax
// DISASM-NEXT: 201007: 49 c7 c7 f8 ff ff ff movq $-8, %r15
// DISASM-NEXT: 20100e: 48 8d 80 f8 ff ff ff leaq -8(%rax), %rax
// DISASM-NEXT: 201015: 4d 8d bf f8 ff ff ff leaq -8(%r15), %r15
// DISASM-NEXT: 20101c: 48 81 c4 f8 ff ff ff addq $-8, %rsp
// DISASM-NEXT: 201023: 49 81 c4 f8 ff ff ff addq $-8, %r12
// DISASM-NEXT: 20102a: 48 c7 c0 fc ff ff ff movq $-4, %rax
// DISASM-NEXT: 201031: 49 c7 c7 fc ff ff ff movq $-4, %r15
// DISASM-NEXT: 201038: 48 8d 80 fc ff ff ff leaq -4(%rax), %rax
// DISASM-NEXT: 20103f: 4d 8d bf fc ff ff ff leaq -4(%r15), %r15
// DISASM-NEXT: 201046: 48 81 c4 fc ff ff ff addq $-4, %rsp
// DISASM-NEXT: 20104d: 49 81 c4 fc ff ff ff addq $-4, %r12

.section .tbss,"awT",@nobits

.type tls0,@object
.align 4
tls0:
 .long 0
 .size tls0, 4

.type  tls1,@object
.align 4
tls1:
 .long 0
 .size tls1, 4

.section .text
.globl _start
_start:
 movq tls0@GOTTPOFF(%rip), %rax
 movq tls0@GOTTPOFF(%rip), %r15
 addq tls0@GOTTPOFF(%rip), %rax
 addq tls0@GOTTPOFF(%rip), %r15
 addq tls0@GOTTPOFF(%rip), %rsp
 addq tls0@GOTTPOFF(%rip), %r12
 movq tls1@GOTTPOFF(%rip), %rax
 movq tls1@GOTTPOFF(%rip), %r15
 addq tls1@GOTTPOFF(%rip), %rax
 addq tls1@GOTTPOFF(%rip), %r15
 addq tls1@GOTTPOFF(%rip), %rsp
 addq tls1@GOTTPOFF(%rip), %r12
