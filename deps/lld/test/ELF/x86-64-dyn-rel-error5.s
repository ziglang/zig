# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64 %s -o %t.o
# RUN: not ld.lld -pie %t.o -o /dev/null 2>&1 | FileCheck %s
# RUN: not ld.lld -shared %t.o -o /dev/null 2>&1 | FileCheck %s

## Check we don't create dynamic relocations in a writable section,
## if the number of bits is smaller than the wordsize.

.globl hidden
.hidden hidden
local:
hidden:

# CHECK: error: relocation R_X86_64_8 cannot be used against local symbol; recompile with -fPIC
# CHECK-NEXT: >>> defined in {{.*}}.o
# CHECK-NEXT: >>> referenced by {{.*}}.o:(.data+0x0)
# CHECK: error: relocation R_X86_64_16 cannot be used against local symbol; recompile with -fPIC
# CHECK: error: relocation R_X86_64_32 cannot be used against local symbol; recompile with -fPIC
# CHECK: error: relocation R_X86_64_32 cannot be used against symbol hidden; recompile with -fPIC

.data
.byte local     # R_X86_64_8
.short local    # R_X86_64_16
.long local     # R_X86_64_32

.long hidden    # R_X86_64_32
