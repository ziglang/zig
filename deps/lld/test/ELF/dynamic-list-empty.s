# REQUIRES: x86

# BFD reports a parse error on empty lists, but it is clear how to
# handle it.

# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: echo "{ };" > %t.list
# RUN: ld.lld -dynamic-list %t.list -shared %t.o -o %t.so
# RUN: llvm-readobj -r %t.so | FileCheck  %s

# CHECK:      Relocations [
# CHECK-NEXT: ]

        .globl foo
foo:
        ret

        call foo@PLT
