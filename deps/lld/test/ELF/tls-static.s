// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %S/Inputs/shared.s -o %tso
// RUN: ld.lld -static %t -o %tout
// RUN: ld.lld %t -o %tout
// RUN: ld.lld -shared %tso -o %tshared
// RUN: ld.lld -static %t %tshared -o %tout

.global _start
_start:
  data16
  leaq  foobar@TLSGD(%rip), %rdi
  data16
  data16
  rex64
  callq  __tls_get_addr@PLT


.section        .tdata,"awT",@progbits
.global  foobar
foobar:
  .long   42
