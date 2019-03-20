# REQUIRES: x86
#
# RUN: llvm-mc -triple=x86_64-windows-gnu %p/Inputs/gnu-implib-head.s -filetype=obj -o %t-dabcdh.o
# RUN: llvm-mc -triple=x86_64-windows-gnu %p/Inputs/gnu-implib-func.s -filetype=obj -o %t-dabcds00000.o
# RUN: llvm-mc -triple=x86_64-windows-gnu %p/Inputs/gnu-implib-tail.s -filetype=obj -o %t-dabcdt.o
# RUN: rm -f %t-implib.a
# RUN: llvm-ar rcs %t-implib.a %t-dabcdh.o %t-dabcds00000.o %t-dabcdt.o
# RUN: llvm-mc -triple=x86_64-windows-gnu %s -filetype=obj -o %t.obj
# RUN: lld-link -out:%t.exe -entry:main -subsystem:console \
# RUN:   %t.obj %t-implib.a
# RUN: llvm-objdump -s %t.exe | FileCheck -check-prefix=DATA %s

        .text
        .global main
main:
        call func
        ret

# Check that the linker inserted the null terminating import descriptor,
# even if there were no normal import libraries, only gnu ones.

# DATA: Contents of section .rdata:
# First import descriptor
# DATA:  140002000 28200000 00000000 00000000 53200000
# Last word from first import descriptor, null terminator descriptor
# DATA:  140002010 38200000 00000000 00000000 00000000
# Null terminator descriptor and import lookup table.
# DATA:  140002020 00000000 00000000 48200000 00000000
