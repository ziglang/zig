# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=i386 %s -o %t.o
# RUN: ld.lld %t.o -shared -o %t.so
# RUN: llvm-objdump -d --no-show-raw-insn %t.so | FileCheck %s

# CHECK: 100b:       movl    (%eax), %eax

# We used to error on R_386_TLS_LDO_32 to preemptable symbols.
# i is STB_GLOBAL and preemptable.
  leal i@TLSLDM(%ebx), %eax
  calll __tls_get_addr@PLT
  movl i@DTPOFF(%eax), %eax # R_386_TLS_LDO_32

.section .tbss,"awT",@nobits
.globl i
i:
  .long 0
  .size i, 4
