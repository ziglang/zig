# REQUIRES: ppc
# RUN: llvm-mc -filetype=obj -triple=powerpc %s -o %t.o

# RUN: ld.lld -shared %t.o -o %t.so
# RUN: llvm-readobj -r %t.so | FileCheck --check-prefix=IE-REL %s
# RUN: llvm-objdump -d --no-show-raw-insn %t.so | FileCheck --check-prefix=IE %s

# RUN: ld.lld %t.o -o %t
# RUN: llvm-readelf -r %t | FileCheck --check-prefix=NOREL %s
# RUN: llvm-objdump -d --no-show-raw-insn %t | FileCheck --check-prefix=LE %s

## A non-preemptable symbol (b) has 0 st_shndx.
# IE-REL:      .rela.dyn {
# IE-REL-NEXT:   0x2005C R_PPC_TPREL32 - 0xC
# IE-REL-NEXT:   0x20058 R_PPC_TPREL32 a 0x0
# IE-REL-NEXT: }

## &.got[0] - _GLOBAL_OFFSET_TABLE_ = 0
# IE:      lwz 10, 0(9)
# IE-NEXT: add 10, 10, 2
## &.got[1] - _GLOBAL_OFFSET_TABLE_ = 4
# IE-NEXT: lwz 8, 4(7)
# IE-NEXT: lbzx 10, 8, 2

# NOREL: no relocations

## a@tprel = st_value(a)-0x7000 = -28664
## b@tprel = st_value(b)-0x7000 = -28660
# LE:      addis 10, 2, 0
# LE-NEXT: addi 10, 10, -28664
# LE-NEXT: addis 8, 2, 0
# LE-NEXT: lbz 10, -28660(8)

lwz 10, a@got@tprel(9)
add 10, 10, a@tls

lwz 8, c@got@tprel(7)
lbzx 10, 8, c@tls

## In IE, these instructions (op rT, rA, x@tls) are not changed.
# IE-NEXT: lhzx 12, 2, 2
# IE-NEXT: lwzx 13, 3, 2
# IE-NEXT: stbx 14, 4, 2
# IE-NEXT: sthx 15, 5, 2
# IE-NEXT: stwx 16, 6, 2

## In LE, these X-Form instructions are changed to their corresponding D-Form.
# LE-NEXT: lhz 12, -28660(2)
# LE-NEXT: lwz 13, -28660(3)
# LE-NEXT: stb 14, -28660(4)
# LE-NEXT: sth 15, -28660(5)
# LE-NEXT: stw 16, -28660(6)

lhzx 12, 2, s@tls
lwzx 13, 3, i@tls
stbx 14, 4, c@tls
sthx 15, 5, s@tls
stwx 16, 6, i@tls

.section .tbss
.globl a
.zero 8
a:
.zero 4
c:
s:
i:
