// REQUIRES: x86
// RUN: llvm-mc %s -o %t.o -filetype=obj --triple=x86_64-unknown-linux
// RUN: ld.lld %t.o -o %t --export-dynamic --gc-sections
// RUN: llvm-readelf -S -s %t | FileCheck %s

// Ordinarily, the TLS and IFUNC sections would be split into partitions.
// Make sure that that didn't happen by checking that there is only one
// of each section.

// CHECK: .ifunc
// CHECK: .tdata

// CHECK-NOT: .ifunc
// CHECK-NOT: .tdata

.section .llvm_sympart.f1,"",@llvm_sympart
.asciz "part1"
.quad f1

.section .text._start,"ax",@progbits
.globl _start
_start:
call tls1
call ifunc1

.section .text.f1,"ax",@progbits
.globl f1
f1:
call tls2
call ifunc2

.section .ifunc,"ax",@progbits,unique,1
.type ifunc1 STT_GNU_IFUNC
ifunc1:

.section .ifunc,"ax",@progbits,unique,2
.type ifunc2 STT_GNU_IFUNC
ifunc2:

.section .tdata,"awT",@progbits,unique,1
tls1:

.section .tdata,"awT",@progbits,unique,2
tls2:
