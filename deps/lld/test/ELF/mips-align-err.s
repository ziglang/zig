# REQUIRES: mips
# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux %s -o %t.o \
# RUN:         -mcpu=mips32r6
# RUN: llvm-mc -filetype=obj -triple=mips-unknown-linux \
# RUN:         -mcpu=mips32r6 %S/Inputs/mips-align-err.s -o %t2.o
# RUN: not ld.lld %t.o %t2.o -o /dev/null 2>&1 | FileCheck %s
# CHECK: {{.*}}:(.text+0x1): improper alignment for relocation R_MIPS_PC16: 0xB is not aligned to 4 bytes

        .globl  __start
__start:
.zero 1
        beqc      $5, $6, _foo            # R_MIPS_PC16
