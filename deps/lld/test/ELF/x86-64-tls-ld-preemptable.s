# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64 %s -o %t.o
# RUN: ld.lld %t.o -shared -o %t.so
# RUN: llvm-objdump -d --no-show-raw-insn %t.so | FileCheck %s

# CHECK:      100c:       leaq    (%rax), %rax
# CHECK-NEXT: 1013:       movabsq 0, %rax

# We used to error on R_X86_64_DTPOFF{32,64} to preemptable symbols.
# i is STB_GLOBAL and preemptable.
  leaq i@TLSLD(%rip), %rdi
  callq __tls_get_addr@PLT
  leaq i@DTPOFF(%rax), %rax # R_X86_64_DTPOFF32
  movabsq i@DTPOFF, %rax # R_X86_64_DTPOFF64

.section .tbss,"awT",@nobits
.globl i
i:
  .long 0
  .size i, 4
