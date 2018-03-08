# Check that we create an error on an out-of-bounds R_MIPS_CALL_16

# REQUIRES: mips
# RUN: llvm-mc -filetype=obj -triple=mips64-unknown-linux %s -o %t1.o
# RUN: not ld.lld %t1.o -o %t.exe 2>&1 | FileCheck %s

# CHECK: relocation R_MIPS_CALL16 out of range: 32768 is not in [-32768, 32767]

.macro generate_values
  .irp i, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,
    .irp j, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,
      .irp k, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,
        .irp l, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,
          .text
          .globl sym_\i\j\k\l
          sym_\i\j\k\l:
          nop
          lw $25,%call16(sym_\i\j\k\l)($28)
        .endr
      .endr
    .endr
  .endr
.endm

generate_values

.globl __start
__start:
  nop
