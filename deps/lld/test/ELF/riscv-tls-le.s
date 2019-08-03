# REQUIRES: riscv

# RUN: llvm-mc -filetype=obj -triple=riscv32 %s -o %t.32.o
# RUN: ld.lld %t.32.o -o %t.32
# RUN: llvm-nm -p %t.32 | FileCheck --check-prefixes=NM %s
# RUN: llvm-objdump -d --no-show-raw-insn %t.32 | FileCheck --check-prefixes=LE %s
# RUN: ld.lld -pie %t.32.o -o %t.32
# RUN: llvm-objdump -d --no-show-raw-insn %t.32 | FileCheck --check-prefixes=LE %s

# RUN: llvm-mc -filetype=obj -triple=riscv64 %s -o %t.64.o
# RUN: ld.lld %t.64.o -o %t.64
# RUN: llvm-objdump -d --no-show-raw-insn %t.64 | FileCheck --check-prefixes=LE %s
# RUN: ld.lld -pie %t.64.o -o %t.64
# RUN: llvm-objdump -d --no-show-raw-insn %t.64 | FileCheck --check-prefixes=LE %s

# NM: {{0*}}00000008 b .LANCHOR0
# NM: {{0*}}0000000c B a

## .LANCHOR0@tprel = 8
## a@tprel = 12
# LE:      lui a5, 0
# LE-NEXT: add a5, a5, tp
# LE-NEXT: addi a5, a5, 8
# LE-NEXT: lui a5, 0
# LE-NEXT: add a5, a5, tp
# LE-NEXT: sw a0, 12(a5)

lui a5, %tprel_hi(.LANCHOR0)
add a5, a5, tp, %tprel_add(.LANCHOR0)
addi a5, a5, %tprel_lo(.LANCHOR0)

lui a5, %tprel_hi(a)
add a5, a5, tp, %tprel_add(a)
sw a0, %tprel_lo(a)(a5)

.section .tbss
.space 8
.LANCHOR0:
.zero 4
.globl a
a:
