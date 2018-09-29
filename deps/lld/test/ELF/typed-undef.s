# REQUIRES: x86

# We used to crash on this, check that we don't

# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld %t.o -o /dev/null -pie --unresolved-symbols=ignore-all

        .global _start
_start:
        .quad foo - .
        .type foo, @object
