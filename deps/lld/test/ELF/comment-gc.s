# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/comment-gc.s -o %t2.o
# RUN: ld.lld %t.o %t2.o -o %t1 --gc-sections -shared
# RUN: llvm-objdump -s %t1 | FileCheck %s

# CHECK:      Contents of section .comment:
# CHECK-NEXT:  0000 00666f6f 00626172 004c4c44 20312e30 .foo.bar.LLD 1.0
# CHECK-NEXT:  0010 00 .

.ident "foo"

.globl _start
_start:
  nop
