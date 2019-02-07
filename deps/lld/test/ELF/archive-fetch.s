# REQUIRES: x86

# We have a code in LLD that prevents fetching the same object from archive file twice.
# This test triggers that code, without it we would fail to link output.

# RUN: echo '.globl foo, bar; foo:' | llvm-mc -filetype=obj -triple=x86_64-unknown-linux - -o %tfoo.o
# RUN: echo '.globl foo, bar; bar:' | llvm-mc -filetype=obj -triple=x86_64-unknown-linux - -o %tbar.o
# RUN: rm -f %t.a
# RUN: llvm-ar rcs %t.a %tfoo.o %tbar.o

# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld %t.a %t.o -o /dev/null

_start:
callq foo
