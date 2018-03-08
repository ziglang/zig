// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
// RUN: ld.lld --hash-style=sysv %t -o %tout -shared
// RUN: llvm-readobj -r %tout | FileCheck %s

 data16
 leaq   g_tls_s@TLSGD(%rip), %rdi
 data16
 data16
 rex64
 callq  __tls_get_addr@PLT

 data16
 leaq   g_tls_s@TLSGD(%rip), %rdi
 data16
 data16
 rex64
 callq  __tls_get_addr@PLT

// Check that we handle two gd relocations to the same symbol.

// CHECK:      Relocations [
// CHECK-NEXT:   Section (4) .rela.dyn {
// CHECK-NEXT:     R_X86_64_DTPMOD64 g_tls_s 0x0
// CHECK-NEXT:     R_X86_64_DTPOFF64 g_tls_s 0x0
// CHECK-NEXT:   }
// CHECK-NEXT:   Section (5) .rela.plt {
// CHECK-NEXT:      R_X86_64_JUMP_SLOT __tls_get_addr 0x0
// CHECK-NEXT:   }
// CHECK-NEXT: ]
