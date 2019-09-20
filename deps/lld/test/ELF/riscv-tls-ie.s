# REQUIRES: riscv

# RUN: llvm-mc -filetype=obj -triple=riscv32 %s -o %t.32.o
## rv32 IE
# RUN: ld.lld -shared %t.32.o -o %t.32.so
# RUN: llvm-readobj -r -d %t.32.so | FileCheck --check-prefix=IE32-REL %s
# RUN: llvm-objdump -d --no-show-raw-insn %t.32.so | FileCheck --check-prefixes=IE,IE32 %s
## rv32 IE -> LE
# RUN: ld.lld %t.32.o -o %t.32
# RUN: llvm-readelf -r %t.32 | FileCheck --check-prefix=NOREL %s
# RUN: llvm-readelf -x .got %t.32 | FileCheck --check-prefix=LE32-GOT %s
# RUN: llvm-objdump -d --no-show-raw-insn %t.32 | FileCheck --check-prefixes=LE,LE32 %s

# RUN: llvm-mc -filetype=obj -triple=riscv64 %s -o %t.64.o
## rv64 IE
# RUN: ld.lld -shared %t.64.o -o %t.64.so
# RUN: llvm-readobj -r -d %t.64.so | FileCheck --check-prefix=IE64-REL %s
# RUN: llvm-objdump -d --no-show-raw-insn %t.64.so | FileCheck --check-prefixes=IE,IE64 %s
## rv64 IE -> LE
# RUN: ld.lld %t.64.o -o %t.64
# RUN: llvm-readelf -r %t.64 | FileCheck --check-prefix=NOREL %s
# RUN: llvm-readelf -x .got %t.64 | FileCheck --check-prefix=LE64-GOT %s
# RUN: llvm-objdump -d --no-show-raw-insn %t.64 | FileCheck --check-prefixes=LE,LE64 %s

# IE32-REL:      .rela.dyn {
# IE32-REL-NEXT:   0x205C R_RISCV_TLS_TPREL32 - 0xC
# IE32-REL-NEXT:   0x2058 R_RISCV_TLS_TPREL32 a 0x0
# IE32-REL-NEXT: }
# IE32-REL:      FLAGS STATIC_TLS

# IE64-REL:      .rela.dyn {
# IE64-REL-NEXT:   0x20B8 R_RISCV_TLS_TPREL64 - 0xC
# IE64-REL-NEXT:   0x20B0 R_RISCV_TLS_TPREL64 a 0x0
# IE64-REL-NEXT: }
# IE64-REL:      FLAGS STATIC_TLS

## rv32: &.got[1] - . = 0x2058 - . = 4096*1+88
## rv64: &.got[1] - . = 0x20B0 - . = 4096*1+176
# IE:        1000: auipc a4, 1
# IE32-NEXT:       lw a4, 88(a4)
# IE64-NEXT:       ld a4, 176(a4)
# IE-NEXT:         add a4, a4, tp
## rv32: &.got[0] - . = 0x205C - . = 4096*1+80
## rv64: &.got[0] - . = 0x20B8 - . = 4096*1+172
# IE:        100c: auipc a5, 1
# IE32-NEXT:       lw a5, 80(a5)
# IE64-NEXT:       ld a5, 172(a5)
# IE-NEXT:         add a5, a5, tp

# NOREL: no relocations

# a@tprel = st_value(a) = 0x8
# b@tprel = st_value(a) = 0xc
# LE32-GOT: section '.got':
# LE32-GOT-NEXT: 0x00012000 08000000 0c000000
# LE64-GOT: section '.got':
# LE64-GOT-NEXT: 0x00012000 08000000 00000000 0c000000 00000000

## rv32: &.got[0] - . = 0x12000 - 0x11000 = 4096*1+0
## rv64: &.got[0] - . = 0x12000 - 0x11000 = 4096*1+0
# LE:        11000: auipc a4, 1
# LE32-NEXT:        lw a4, 0(a4)
# LE64-NEXT:        ld a4, 0(a4)
# LE-NEXT:          add a4, a4, tp
## rv32: &.got[1] - . = 0x12004 - 0x1100c = 4096*1-8
## rv64: &.got[1] - . = 0x12008 - 0x1100c = 4096*1-4
# LE:        1100c: auipc a5, 1
# LE32-NEXT:        lw a5, -8(a5)
# LE64-NEXT:        ld a5, -4(a5)
# LE-NEXT:          add a5, a5, tp

la.tls.ie a4,a
add a4,a4,tp
la.tls.ie a5,b
add a5,a5,tp

.section .tbss
.globl a
.zero 8
a:
.zero 4
b:
