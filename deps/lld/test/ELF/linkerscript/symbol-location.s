# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: echo "foo = 1;" > %t.script
# RUN: not ld.lld -pie -o %t --script %t.script %t.o 2>&1 | FileCheck %s

## Here we check that symbol 'foo' location is reported properly.

# CHECK: error: relocation R_X86_64_PLT32 cannot refer to absolute symbol: foo
# CHECK: >>> defined in {{.*}}.script:1
# CHECK: >>> referenced by {{.*}}.o:(.text+0x1)

.text
.globl _start
_start:
 call foo@PLT
