# REQUIRES: riscv
# RUN: echo '.tbss; .globl b, c; b: .zero 4; c:' > %t.s
# RUN: echo '.globl __tls_get_addr; __tls_get_addr:' > %tga.s

## RISC-V psABI doesn't specify TLS relaxation. Though the code sequences are not
## relaxed, dynamic relocations can be omitted for GD->LE relaxation.

# RUN: llvm-mc -filetype=obj -triple=riscv32 %s -o %t.32.o
# RUN: llvm-mc -filetype=obj -triple=riscv32 %t.s -o %t1.32.o
# RUN: ld.lld -shared -soname=t1.so %t1.32.o -o %t1.32.so
# RUN: llvm-mc -filetype=obj -triple=riscv32 %tga.s -o %tga.32.o
## rv32 GD
# RUN: ld.lld -shared %t.32.o %t1.32.o -o %t.32.so
# RUN: llvm-readobj -r %t.32.so | FileCheck --check-prefix=GD32-REL %s
# RUN: llvm-objdump -d --no-show-raw-insn %t.32.so | FileCheck --check-prefix=GD32 %s
## rv32 GD -> LE
# RUN: ld.lld %t.32.o %t1.32.o %tga.32.o -o %t.32
# RUN: llvm-readelf -r %t.32 | FileCheck --check-prefix=NOREL %s
# RUN: llvm-readelf -x .got %t.32 | FileCheck --check-prefix=LE32-GOT %s
# RUN: ld.lld -pie %t.32.o %t1.32.o %tga.32.o -o %t.32
# RUN: llvm-readelf -r %t.32 | FileCheck --check-prefix=NOREL %s
# RUN: llvm-readelf -x .got %t.32 | FileCheck --check-prefix=LE32-GOT %s
## rv32 GD -> IE
# RUN: ld.lld %t.32.o %t1.32.so %tga.32.o -o %t.32
# RUN: llvm-readobj -r %t.32 | FileCheck --check-prefix=IE32-REL %s
# RUN: llvm-readelf -x .got %t.32 | FileCheck --check-prefix=IE32-GOT %s

# RUN: llvm-mc -filetype=obj -triple=riscv64 %s -o %t.64.o
# RUN: llvm-mc -filetype=obj -triple=riscv64 %t.s -o %t1.64.o
# RUN: ld.lld -shared -soname=t1.so %t1.64.o -o %t1.64.so
# RUN: llvm-mc -filetype=obj -triple=riscv64 %tga.s -o %tga.64.o
## rv64 GD
# RUN: ld.lld -shared %t.64.o %t1.64.o -o %t.64.so
# RUN: llvm-readobj -r %t.64.so | FileCheck --check-prefix=GD64-REL %s
# RUN: llvm-objdump -d --no-show-raw-insn %t.64.so | FileCheck --check-prefix=GD64 %s
## rv64 GD -> LE
# RUN: ld.lld %t.64.o %t1.64.o %tga.64.o -o %t.64
# RUN: llvm-readelf -r %t.64 | FileCheck --check-prefix=NOREL %s
# RUN: llvm-readelf -x .got %t.64 | FileCheck --check-prefix=LE64-GOT %s
# RUN: ld.lld -pie %t.64.o %t1.64.o %tga.64.o -o %t.64
# RUN: llvm-readelf -r %t.64 | FileCheck --check-prefix=NOREL %s
# RUN: llvm-readelf -x .got %t.64 | FileCheck --check-prefix=LE64-GOT %s
## rv64 GD -> IE
# RUN: ld.lld %t.64.o %t1.64.so %tga.64.o -o %t.64
# RUN: llvm-readobj -r %t.64 | FileCheck --check-prefix=IE64-REL %s
# RUN: llvm-readelf -x .got %t.64 | FileCheck --check-prefix=IE64-GOT %s

# GD32-REL:      .rela.dyn {
# GD32-REL-NEXT:   0x2070 R_RISCV_TLS_DTPMOD32 a 0x0
# GD32-REL-NEXT:   0x2074 R_RISCV_TLS_DTPREL32 a 0x0
# GD32-REL-NEXT:   0x2078 R_RISCV_TLS_DTPMOD32 b 0x0
# GD32-REL-NEXT:   0x207C R_RISCV_TLS_DTPREL32 b 0x0
# GD32-REL-NEXT: }

## &DTPMOD(a) - . = 0x2070 - 0x1000 = 4096*1+112
# GD32:      1000: auipc a0, 1
# GD32-NEXT:       addi a0, a0, 112
# GD32-NEXT:       auipc ra, 0
# GD32-NEXT:       jalr 56(ra)

## &DTPMOD(b) - . = 0x2078 - 0x1010 = 4096*1+104
# GD32:      1010: auipc a0, 1
# GD32-NEXT:       addi a0, a0, 104
# GD32-NEXT:       auipc ra, 0
# GD32-NEXT:       jalr 40(ra)

# GD64-REL:      .rela.dyn {
# GD64-REL-NEXT:   0x20E0 R_RISCV_TLS_DTPMOD64 a 0x0
# GD64-REL-NEXT:   0x20E8 R_RISCV_TLS_DTPREL64 a 0x0
# GD64-REL-NEXT:   0x20F0 R_RISCV_TLS_DTPMOD64 b 0x0
# GD64-REL-NEXT:   0x20F8 R_RISCV_TLS_DTPREL64 b 0x0
# GD64-REL-NEXT: }

## &DTPMOD(a) - . = 0x20e0 - 0x1000 = 4096*1+224
# GD64:      1000: auipc a0, 1
# GD64-NEXT:       addi a0, a0, 224
# GD64-NEXT:       auipc ra, 0
# GD64-NEXT:       jalr 56(ra)

## &DTPMOD(b) - . = 0x20f0 - 0x1010 = 4096*1+224
# GD64:      1010: auipc a0, 1
# GD64-NEXT:       addi a0, a0, 224
# GD64-NEXT:       auipc ra, 0
# GD64-NEXT:       jalr 40(ra)

# NOREL: no relocations

## .got contains pre-populated values: [a@dtpmod, a@dtprel, b@dtpmod, b@dtprel]
## a@dtprel = st_value(a)-0x800 = 0xfffff808
## b@dtprel = st_value(b)-0x800 = 0xfffff80c
# LE32-GOT: section '.got':
# LE32-GOT-NEXT: 0x{{[0-9a-f]+}} 01000000 08f8ffff 01000000 0cf8ffff
# LE64-GOT: section '.got':
# LE64-GOT-NEXT: 0x{{[0-9a-f]+}} 01000000 00000000 08f8ffff ffffffff
# LE64-GOT-NEXT: 0x{{[0-9a-f]+}} 01000000 00000000 0cf8ffff ffffffff

## a is local - relaxed to LE - its DTPMOD/DTPREL slots are link-time constants.
## b is external - DTPMOD/DTPREL dynamic relocations are required.
# IE32-REL:      .rela.dyn {
# IE32-REL-NEXT:   0x12068 R_RISCV_TLS_DTPMOD32 b 0x0
# IE32-REL-NEXT:   0x1206C R_RISCV_TLS_DTPREL32 b 0x0
# IE32-REL-NEXT: }
# IE32-GOT:      section '.got':
# IE32-GOT-NEXT: 0x00012060 01000000 08f8ffff 00000000 00000000

# IE64-REL:      .rela.dyn {
# IE64-REL-NEXT:   0x120D0 R_RISCV_TLS_DTPMOD64 b 0x0
# IE64-REL-NEXT:   0x120D8 R_RISCV_TLS_DTPREL64 b 0x0
# IE64-REL-NEXT: }
# IE64-GOT:      section '.got':
# IE64-GOT-NEXT: 0x000120c0 01000000 00000000 08f8ffff ffffffff
# IE64-GOT-NEXT: 0x000120d0 00000000 00000000 00000000 00000000

la.tls.gd a0,a
call __tls_get_addr@plt

la.tls.gd a0,b
call __tls_get_addr@plt

.section .tbss
.globl a
.zero 8
a:
.zero 4
