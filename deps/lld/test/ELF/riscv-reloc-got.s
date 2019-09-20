# REQUIRES: riscv
# RUN: echo '.globl b; b:' | llvm-mc -filetype=obj -triple=riscv32 - -o %t1.o
# RUN: ld.lld -shared %t1.o -o %t1.so

# RUN: llvm-mc -filetype=obj -triple=riscv32 -position-independent %s -o %t.o
# RUN: ld.lld %t.o %t1.so -o %t
# RUN: llvm-readobj -r %t | FileCheck --check-prefix=RELOC32 %s
# RUN: llvm-nm %t | FileCheck --check-prefix=NM %s
# RUN: llvm-readobj -x .got %t | FileCheck --check-prefix=HEX32 %s
# RUN: llvm-objdump -d --no-show-raw-insn %t | FileCheck --check-prefix=DIS32 %s

# RUN: echo '.globl b; b:' | llvm-mc -filetype=obj -triple=riscv64 - -o %t1.o
# RUN: ld.lld -shared %t1.o -o %t1.so

# RUN: llvm-mc -filetype=obj -triple=riscv64 -position-independent %s -o %t.o
# RUN: ld.lld %t.o %t1.so -o %t
# RUN: llvm-readobj -r %t | FileCheck --check-prefix=RELOC64 %s
# RUN: llvm-nm %t | FileCheck --check-prefix=NM %s
# RUN: llvm-readobj -x .got %t | FileCheck --check-prefix=HEX64 %s
# RUN: llvm-objdump -d --no-show-raw-insn %t | FileCheck --check-prefix=DIS64 %s

# SEC: .got PROGBITS 00012060 020060 00000c

# RELOC32:      .rela.dyn {
# RELOC32-NEXT:   0x12068 R_RISCV_32 b 0x0
# RELOC32-NEXT: }

# RELOC64:      .rela.dyn {
# RELOC64-NEXT:   0x120D0 R_RISCV_64 b 0x0
# RELOC64-NEXT: }

# NM: 00013000 d a

## .got[0] = _DYNAMIC
## .got[1] = a (filled at link time)
## .got[2] = 0 (relocated by R_RISCV_64 at runtime)
# HEX32: section '.got':
# HEX32: 0x00012060 00200100 00300100 00000000

# HEX64: section '.got':
# HEX64: 0x000120c0 00200100 00000000 00300100 00000000
# HEX64: 0x000120d0 00000000 00000000

## &.got[1]-. = 0x12060-0x11000 = 4096*1+100
# DIS32:      11000: auipc a0, 1
# DIS32-NEXT:        lw a0, 100(a0)
## &.got[2]-. = 0x12064-0x11008 = 4096*1+96
# DIS32:      11008: auipc a0, 1
# DIS32-NEXT:        lw a0, 96(a0)

## &.got[1]-. = 0x120c8-0x11000 = 4096*1+100
# DIS64:      11000: auipc a0, 1
# DIS64-NEXT:        ld a0, 200(a0)
## &.got[2]-. = 0x120d0-0x11008 = 4096*1+200
# DIS64:      11008: auipc a0, 1
# DIS64-NEXT:        ld a0, 200(a0)

la a0,a
la a0,b

.data
a:
## An undefined reference of _GLOBAL_OFFSET_TABLE_ causes .got[0] to be
## allocated to store _DYNAMIC.
.long _GLOBAL_OFFSET_TABLE_ - .
