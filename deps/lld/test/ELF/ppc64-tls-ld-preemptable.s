# REQUIRES: ppc
# RUN: llvm-mc -filetype=obj -triple=ppc64le %s -o %t.o
# RUN: ld.lld %t.o -shared -o %t.so
# RUN: llvm-objdump -d --no-show-raw-insn %t.so | FileCheck %s
# RUN: llvm-nm %t.so | FileCheck --check-prefix=NM %s
# RUN: llvm-readelf -x .rodata %t.so | FileCheck --check-prefix=RODATA %s

# 0x2a - 0x8000 = -32726
# CHECK:      addis 4, 3, 0
# CHECK-NEXT: addi 4, 4, -32726
# CHECK-NEXT: lis 5, 0
# CHECK-NEXT: ori 5, 5, 0

# NM: 000000000000002a B i
# RODATA: 2a000000 00000000

# We used to error on R_PPC64_DTPREL* to preemptable symbols.
# i is STB_GLOBAL and preemptable.
.globl foo
foo:
  addis 4, 3, i@dtprel@ha # R_PPC64_DTPREL16_HA
  addi 4, 4, i@dtprel@l   # R_PPC64_DTPREL16_LO

  lis 5, i@dtprel@highesta # R_PPC64_DTPREL16_HIGHESTA
  ori 5, 5, i@dtprel@highera # R_PPC64_DTPREL16_HIGHERA

.section .rodata,"a",@progbits
  .quad i@dtprel+32768

.section .tbss,"awT",@nobits
  .space 0x2a
.globl i
i:
  .long 0
  .size i, 4
