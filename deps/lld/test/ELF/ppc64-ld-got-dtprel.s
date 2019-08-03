# REQUIRES: ppc

# RUN: llvm-mc -filetype=obj -triple=powerpc64le %s -o %t.o
# RUN: llvm-readobj -r %t.o | FileCheck --check-prefix=RELOCS %s
# RUN: ld.lld -shared %t.o -o %t.so
# RUN: llvm-objdump -d --no-show-raw-insn %t.so | FileCheck %s
## Check LD->LE relaxation does not affect R_PPC64_GOT_DTPREL16*.
# RUN: ld.lld %t.o -o %t
# RUN: llvm-objdump -d --no-show-raw-insn %t | FileCheck %s

# RUN: llvm-mc -filetype=obj -triple=powerpc64 %s -o %t.o
# RUN: llvm-readobj -r %t.o | FileCheck --check-prefix=RELOCS %s
# RUN: ld.lld -shared %t.o -o %t.so
# RUN: llvm-objdump -d --no-show-raw-insn %t.so | FileCheck %s
# RUN: ld.lld %t.o -o %t
# RUN: llvm-objdump -d --no-show-raw-insn %t | FileCheck %s

# RELOCS:      .rela.text {
# RELOCS-NEXT:   R_PPC64_GOT_DTPREL16_HA i 0x0
# RELOCS-NEXT:   R_PPC64_GOT_DTPREL16_LO_DS i 0x0
# RELOCS-NEXT:   R_PPC64_GOT_DTPREL16_HI j 0x0
# RELOCS-NEXT:   R_PPC64_GOT_DTPREL16_DS j 0x0
# RELOCS-NEXT: }

## ha(i@got@dtprel) = (&.got[0] - (.got+0x8000) + 0x8000 >> 16) & 0xffff = 0
## lo(i@got@dtprel) = &.got[0] - (.got+0x8000) & 0xffff = -32768
## hi(j@got@dtprel) = (&.got[1] - (.got+0x8000) >> 16) & 0xffff = -1
## j@got@dtprel = &.got[1] - (.got+0x8000) = -32760
# CHECK:      addis 3, 2, 0
# CHECK-NEXT: ld 3, -32768(3)
# CHECK-NEXT: addis 3, 2, -1
# CHECK-NEXT: addi 3, 2, -32760

  addis 3, 2, i@got@dtprel@ha
  ld 3, i@got@dtprel@l(3)
  addis 3, 2, j@got@dtprel@h
  addi 3, 2, j@got@dtprel

.section .tbss,"awT",@progbits
.p2align 2
i:
  .long 0
j:
  .long 0
