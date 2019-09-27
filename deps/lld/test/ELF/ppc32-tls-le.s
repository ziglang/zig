# REQUIRES: ppc
# RUN: llvm-mc -filetype=obj -triple=powerpc %s -o %t.o
# RUN: ld.lld %t.o -o %t
# RUN: llvm-objdump -d --no-show-raw-insn %t | FileCheck --check-prefix=LE %s

## a@tprel = st_value(a)-0x7000 = -28664
## b@tprel = st_value(b)-0x7000 = -28660
# LE:      addis 9, 2, 0
# LE-NEXT: addi 9, 9, -28664
# LE-NEXT: addis 10, 2, 0
# LE-NEXT: lwz 9, -28660(10)

addis 9, 2, a@tprel@ha
addi 9, 9, a@tprel@l

addis 10, 2, b@tprel@ha
lwz 9,b@tprel@l(10)

.section .tbss
.globl a
.zero 8
a:
.zero 4
b:
