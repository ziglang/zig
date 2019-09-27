# REQUIRES: riscv
# RUN: echo '.tbss; .globl b, c; b: .zero 4; c:' > %t.s
# RUN: echo '.globl __tls_get_addr; __tls_get_addr:' > %tga.s

## RISC-V psABI doesn't specify TLS relaxation. Though the code sequences are not
## relaxed, dynamic relocations can be omitted for LD->LE relaxation.
## LD uses the same relocation as GD: R_RISCV_GD_HI20, the difference is that it
## references a local symbol (.LANCHOR0).

# RUN: llvm-mc -filetype=obj -triple=riscv32 -position-independent %s -o %t.32.o
# RUN: llvm-mc -filetype=obj -triple=riscv32 %tga.s -o %tga.o
## rv32 LD
# RUN: ld.lld -shared %t.32.o -o %t.32.so
# RUN: llvm-readobj -r %t.32.so | FileCheck --check-prefix=LD32-REL %s
# RUN: llvm-readelf -x .got %t.32.so | FileCheck --check-prefix=LD32-GOT %s
# RUN: llvm-objdump -d --no-show-raw-insn %t.32.so | FileCheck --check-prefixes=LD,LD32 %s
## rv32 LD -> LE
# RUN: ld.lld %t.32.o %tga.o -o %t.32
# RUN: llvm-readelf -r %t.32 | FileCheck --check-prefix=NOREL %s
# RUN: llvm-readelf -x .got %t.32 | FileCheck --check-prefix=LE32-GOT %s
# RUN: llvm-objdump -d --no-show-raw-insn %t.32 | FileCheck --check-prefixes=LE,LE32 %s

# RUN: llvm-mc -filetype=obj -triple=riscv64 -position-independent %s -o %t.64.o
# RUN: llvm-mc -filetype=obj -triple=riscv64 %tga.s -o %tga.o
## rv64 LD
# RUN: ld.lld -shared %t.64.o -o %t.64.so
# RUN: llvm-readobj -r %t.64.so | FileCheck --check-prefix=LD64-REL %s
# RUN: llvm-readelf -x .got %t.64.so | FileCheck --check-prefix=LD64-GOT %s
# RUN: llvm-objdump -d --no-show-raw-insn %t.64.so | FileCheck --check-prefixes=LD,LD64 %s
## rv64 LD -> LE
# RUN: ld.lld %t.64.o %tga.o -o %t.64
# RUN: llvm-readelf -r %t.64 | FileCheck --check-prefix=NOREL %s
# RUN: llvm-readelf -x .got %t.64 | FileCheck --check-prefix=LE64-GOT %s
# RUN: llvm-objdump -d --no-show-raw-insn %t.64 | FileCheck --check-prefixes=LE,LE64 %s

## a@dtprel = st_value(a)-0x800 = 0xfffff808 is a link-time constant.
# LD32-REL:      .rela.dyn {
# LD32-REL-NEXT:   0x2084
# LD32-REL-NEXT:   0x207C R_RISCV_TLS_DTPMOD32 - 0x0
# LD32-REL-NEXT: }
# LD32-GOT:      section '.got':
# LD32-GOT-NEXT: 0x00002078 00200000 00000000 00f8ffff 00000000

# LD64-REL:      .rela.dyn {
# LD64-REL-NEXT:   0x2108
# LD64-REL-NEXT:   0x20F8 R_RISCV_TLS_DTPMOD64 - 0x0
# LD64-REL-NEXT: }
# LD64-GOT:      section '.got':
# LD64-GOT-NEXT: 0x000020f0 00200000 00000000 00000000 00000000
# LD64-GOT-NEXT: 0x00002100 00f8ffff ffffffff 00000000 00000000

## rv32: &DTPMOD(a) - . = 0x207c - 0x1000 = 4096*1+124
## rv64: &DTPMOD(a) - . = 0x20e0 - 0x1000 = 4096*1+248
# LD:        1000: auipc a0, 1
# LD32-NEXT:       addi a0, a0, 124
# LD64-NEXT:       addi a0, a0, 248
# LD-NEXT:         auipc ra, 0
# LD-NEXT:         jalr 56(ra)

# NOREL: no relocations

## a is local - its DTPMOD/DTPREL slots are link-time constants.
## a@dtpmod = 1 (main module)
# LE32-GOT: section '.got':
# LE32-GOT-NEXT: 0x00012000 00000000 01000000 00f8ffff 00200100

# LE64-GOT: section '.got':
# LE64-GOT-NEXT: 0x00012000 00000000 00000000 01000000 00000000
# LE64-GOT-NEXT: 0x00012010 00f8ffff ffffffff 00200100 00000000

## rv32: DTPMOD(.LANCHOR0) - . = 0x12004 - 0x11000 = 4096*1+4
## rv64: DTPMOD(.LANCHOR0) - . = 0x12008 - 0x11000 = 4096*1+8
# LE:        11000: auipc a0, 1
# LE32-NEXT:        addi a0, a0, 4
# LE64-NEXT:        addi a0, a0, 8
# LE-NEXT:          auipc ra, 0
# LE-NEXT:          jalr 24(ra)

la.tls.gd a0, .LANCHOR0
call __tls_get_addr@plt
lw a4, 0(a0)
lh a0, 4(a0)

## This is irrelevant to TLS. We use it to take 2 GOT slots to check DTPREL
## offsets are correct.
la a5, _GLOBAL_OFFSET_TABLE_

.section .tbss,"awT",@nobits
.set .LANCHOR0, . + 0
.zero 8
