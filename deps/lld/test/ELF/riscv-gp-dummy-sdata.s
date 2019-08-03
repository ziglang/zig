# REQUIRES: riscv
# RUN: llvm-mc -filetype=obj -triple=riscv32 %s -o %t.32.o
# RUN: ld.lld -pie %t.32.o -o %t.32
# RUN: llvm-readelf -S %t.32 | FileCheck --check-prefix=SEC %s
# RUN: llvm-readelf -s %t.32 | FileCheck --check-prefix=SYM %s

# RUN: llvm-mc -filetype=obj -triple=riscv64 %s -o %t.64.o
# RUN: ld.lld -pie %t.64.o -o %t.64
# RUN: llvm-readelf -S %t.64 | FileCheck --check-prefix=SEC %s
# RUN: llvm-readelf -s %t.64 | FileCheck --check-prefix=SYM %s

## If there is an undefined reference to __global_pointer$ but .sdata doesn't
## exist, create a dummy one.

## __global_pointer$ = .sdata+0x800
# SEC: [ 7] .sdata PROGBITS {{0*}}00003000
# SYM: {{0*}}00003800 0 NOTYPE GLOBAL DEFAULT 7 __global_pointer$

## If __global_pointer$ is not used, don't create .sdata .

# RUN: llvm-mc -filetype=obj -triple=riscv32 /dev/null -o %t.32.o
# RUN: ld.lld -pie %t.32.o -o %t.32
# RUN: llvm-readelf -S %t.32 | FileCheck --implicit-check-not=.sdata /dev/null

lla gp, __global_pointer$
