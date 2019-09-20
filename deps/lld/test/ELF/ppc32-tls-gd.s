# REQUIRES: ppc
# RUN: llvm-mc -filetype=obj -triple=powerpc %s -o %t.o
# RUN: echo '.tbss; .globl b, c; b: .zero 4; c:' | llvm-mc -filetype=obj -triple=powerpc - -o %t1.o
# RUN: ld.lld -shared -soname=t1.so %t1.o -o %t1.so
# RUN: echo '.globl __tls_get_addr; __tls_get_addr:' | llvm-mc -filetype=obj -triple=powerpc - -o %tga.o

# RUN: ld.lld -shared %t.o %t1.o -o %t.so
# RUN: llvm-readobj -d %t.so | FileCheck --check-prefix=GD-DYN %s
# RUN: llvm-readobj -r %t.so | FileCheck --check-prefix=GD-REL %s
# RUN: llvm-objdump -d --no-show-raw-insn %t.so | FileCheck --check-prefix=GD %s

# RUN: ld.lld %t.o %t1.o %tga.o -o %t
# RUN: llvm-readelf -r %t | FileCheck --check-prefix=NOREL %s
# RUN: llvm-objdump -d --no-show-raw-insn %t | FileCheck --check-prefix=LE %s

# RUN: ld.lld %t.o %t1.so -o %t
# RUN: llvm-readobj -r %t | FileCheck --check-prefix=IE-REL %s
# RUN: llvm-objdump -d --no-show-raw-insn %t | FileCheck --check-prefix=IE %s

## DT_PPC_GOT represents the address of _GLOBAL_OFFSET_TABLE_.
# GD-DYN: PPC_GOT 0x20078

# GD-REL:      .rela.dyn {
# GD-REL-NEXT:   0x20078 R_PPC_DTPMOD32 a 0x0
# GD-REL-NEXT:   0x2007C R_PPC_DTPREL32 a 0x0
# GD-REL-NEXT:   0x20080 R_PPC_DTPMOD32 b 0x0
# GD-REL-NEXT:   0x20084 R_PPC_DTPREL32 b 0x0
# GD-REL-NEXT:   0x20088 R_PPC_DTPMOD32 c 0x0
# GD-REL-NEXT:   0x2008C R_PPC_DTPREL32 c 0x0
# GD-REL-NEXT: }

## &DTPMOD(a) - _GLOBAL_OFFSET_TABLE_ = 0x20078 - 0x20078 = 0
# GD:      addi 3, 31, 0
# GD-NEXT: bl .+32
# GD-NEXT: lwz 3, 0(3)

## &DTPMOD(b) - _GLOBAL_OFFSET_TABLE_ = 0x20080 - 0x20078 = 8
# GD-NEXT: addi 3, 31, 8
# GD-NEXT: bl .+20
# GD-NEXT: lwz 3, 0(3)

## &DTPMOD(c) - _GLOBAL_OFFSET_TABLE_ = 0x20088 - 0x20078 = 16
# GD-NEXT: addi 3, 9, 16
# GD-NEXT: bl .+8
# GD-NEXT: lwz 3, 0(3)

# NOREL: no relocations

## a@tprel = 8-0x7000 = -28664
# LE:      addis 3, 2, 0
# LE-NEXT: addi 3, 3, -28664
# LE-NEXT: lwz 3, 0(3)
## b@tprel = 12-0x7000 = -28660
# LE-NEXT: addis 3, 2, 0
# LE-NEXT: addi 3, 3, -28660
# LE-NEXT: lwz 3, 0(3)
## c@tprel = 16-0x7000 = -28656
# LE-NEXT: addis 3, 2, 0
# LE-NEXT: addi 3, 3, -28656
# LE-NEXT: lwz 3, 0(3)

# IE-REL:      .rela.dyn {
# IE-REL-NEXT:   0x10020068 R_PPC_TPREL32 b 0x0
# IE-REL-NEXT:   0x1002006C R_PPC_TPREL32 c 0x0
# IE-REL-NEXT: }

## a is relaxed to use LE.
## a@tprel = st_value(a)-0x8000 = -28664
# IE:      addis 3, 2, 0
# IE-NEXT: addi 3, 3, -28664
# IE-NEXT: lwz 3, 0(3)
## &.got[0] - _GLOBAL_OFFSET_TABLE_ = 0
# IE-NEXT: lwz 3, 0(31)
# IE-NEXT: add 3, 3, 2
# IE-NEXT: lwz 3, 0(3)
## &.got[1] - _GLOBAL_OFFSET_TABLE_ = 4
# IE-NEXT: lwz 3, 4(9)
# IE-NEXT: add 3, 3, 2
# IE-NEXT: lwz 3, 0(3)

addi 3, 31, a@got@tlsgd
bl __tls_get_addr(a@tlsgd)
lwz 3, 0(3)

addi 3, 31, b@got@tlsgd
bl __tls_get_addr(b@tlsgd)
lwz 3, 0(3)

## -fpic may use a different register (e.g. r9).
addi 3, 9, c@got@tlsgd
bl __tls_get_addr(c@tlsgd)
lwz 3, 0(3)

.section .tbss
.globl a
.zero 8
a:
.zero 4
