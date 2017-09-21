// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/tls-got-entry.s -o %tso.o
// RUN: ld.lld -shared %tso.o -o %t.so
// RUN: ld.lld %t.o %t.so -o %t1
// RUN: llvm-readobj -r %t1 | FileCheck %s

// CHECK:      Relocations [
// CHECK-NEXT:   Section ({{.*}}) .rela.dyn {
// CHECK-NEXT:     R_X86_64_TPOFF64 tlsshared0 0x0
// CHECK-NEXT:   }
// CHECK-NEXT: ]

.globl _start
_start:
 .byte 0x66
 leaq tlsshared0@tlsgd(%rip),%rdi
 .word 0x6666
 rex64
 call __tls_get_addr@plt
 .byte 0x66
 leaq tlsshared0@tlsgd(%rip),%rdi
 .word 0x6666
 rex64
 call __tls_get_addr@plt
