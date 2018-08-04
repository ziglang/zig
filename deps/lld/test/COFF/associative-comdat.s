# REQUIRES: x86
# RUN: llvm-mc -triple=x86_64-windows-msvc %s -filetype=obj -o %t1.obj
# RUN: llvm-mc -triple=x86_64-windows-msvc %S/Inputs/associative-comdat-2.s -filetype=obj -o %t2.obj

# RUN: lld-link -entry:main %t1.obj %t2.obj -out:%t.gc.exe
# RUN: llvm-readobj -sections %t.gc.exe | FileCheck %s

# RUN: lld-link -entry:main %t1.obj %t2.obj -opt:noref -out:%t.nogc.exe
# RUN: llvm-readobj -sections %t.nogc.exe | FileCheck %s

# CHECK: Sections [
# CHECK:   Section {
# CHECK:     Number: 2
# CHECK-LABEL:     Name: .rdata (2E 72 64 61 74 61 00 00)
#             This is the critical check to show that only *one* definition of
#             foo_assoc was retained. This *must* be 8, not 16.
# CHECK-NEXT:     VirtualSize: 0x8
# CHECK:   Section {
# CHECK:     Number: 3
# CHECK-LABEL:     Name: .data (2E 64 61 74 61 00 00 00)
# CHECK-NEXT:     VirtualSize: 0x4

        .text
        .def     main;
        .scl    2;
        .type   32;
        .endef
        .globl  main                    # -- Begin function main
        .p2align        4, 0x90
main:                                   # @main
# BB#0:
        movl    foo(%rip), %eax
        retq
                                        # -- End function

# Defines foo and foo_assoc globals. foo is comdat, and foo_assoc is comdat
# associative with it. foo_assoc should be discarded iff foo is discarded,
# either by linker GC or normal comdat merging.

        .section        .rdata,"dr",associative,foo
        .p2align        3
        .quad   foo

        .section        .data,"dw",discard,foo
        .globl  foo                     # @foo
        .p2align        2
foo:
        .long   42
