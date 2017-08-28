# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t

# RUN: ld.lld -N -Ttext 0x100 -o %t.out %t --oformat binary
# RUN: od -t x1 -v %t.out | FileCheck %s --check-prefix=BIN

# BIN:      0000000 90 00 00 00 00 00 00 00
# BIN-NEXT: 0000010
# BIN-NOT:  0000020

## The same but without OMAGIC.
# RUN: ld.lld -Ttext 0x100 -o %t.out %t --oformat binary
# RUN: od -t x1 -v %t.out | FileCheck %s --check-prefix=BIN

.text
.globl _start
_start:
 nop
