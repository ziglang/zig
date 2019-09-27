# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld %t.o -o %t --export-dynamic
# RUN: llvm-readelf -r %t | FileCheck %s

## gABI leaves the behavior of weak undefined references implementation defined.
## We choose to resolve it statically and not create a dynamic relocation for
## implementation simplicity. This also matches ld.bfd and gold.

# CHECK: no relocations

        .global _start
_start:
        .data
        .weak foobar
        .quad foobar
