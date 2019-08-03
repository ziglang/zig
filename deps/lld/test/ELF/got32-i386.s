# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=i686-pc-linux %s -o %t.o
# RUN: ld.lld %t.o -o %t
# RUN: llvm-objdump -section-headers -d %t | FileCheck %s

## We have R_386_GOT32 relocation here.
.globl foo
.type foo, @function
foo:
 nop

_start:
 movl foo@GOT, %ebx

## 73728 == 0x12000 == ADDR(.got)
# CHECK:       _start:
# CHECK-NEXT:   401001: 8b 1d {{.*}}  movl 4202496, %ebx
# CHECK: Sections:
# CHECK:  Name Size     VMA
# CHECK:  .got 00000004 0000000000402000

# RUN: not ld.lld %t.o -o %t -pie 2>&1 | FileCheck %s --check-prefix=ERR
# ERR: error: can't create dynamic relocation R_386_GOT32 against symbol: foo in readonly segment; recompile object files with -fPIC or pass '-Wl,-z,notext' to allow text relocations in the output
