// REQUIRES: x86
// RUN: llvm-mc %s -o %t.o -triple x86_64-pc-linux -filetype=obj
// RUN: ld.lld %t.o -o /dev/null

// Don't error if __tls_get_addr is defined.

.global _start
.global __tls_get_addr
_start:
__tls_get_addr:
nop
