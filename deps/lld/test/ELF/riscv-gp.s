# REQUIRES: riscv
# RUN: llvm-mc -filetype=obj -triple=riscv32 %s -o %t.32.o
# RUN: ld.lld -pie %t.32.o -o %t.32
# RUN: llvm-readelf -s %t.32 | FileCheck --check-prefix=SYM %s
# RUN: llvm-readelf -S %t.32 | FileCheck --check-prefix=SEC %s
# RUN: not ld.lld -shared %t.32.o -o /dev/null 2>&1 | FileCheck --check-prefix=ERR %s

# RUN: llvm-mc -filetype=obj -triple=riscv64 %s -o %t.64.o
# RUN: ld.lld -pie %t.64.o -o %t.64
# RUN: llvm-readelf -s %t.64 | FileCheck --check-prefix=SYM %s
# RUN: llvm-readelf -S %t.64 | FileCheck --check-prefix=SEC %s
# RUN: not ld.lld -shared %t.64.o -o /dev/null 2>&1 | FileCheck --check-prefix=ERR %s

## __global_pointer$ = .sdata+0x800 = 0x3800
# SEC: [ 7] .sdata PROGBITS {{0*}}00003000
# SYM: {{0*}}00003800 0 NOTYPE GLOBAL DEFAULT 7 __global_pointer$

## __global_pointer$ - 0x1000 = 4096*3-2048
# DIS:      1000: auipc gp, 3
# DIS-NEXT:       addi gp, gp, -2048

# ERR: error: relocation R_RISCV_PCREL_HI20 cannot be used against symbol __global_pointer$; recompile with -fPIC

lla gp, __global_pointer$

.section .sdata,"aw"
