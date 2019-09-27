# REQUIRES: x86

# RUN: llvm-mc -triple=x86_64-windows-gnu %s -filetype=obj -o %t1.obj
# RUN: llvm-mc -triple=x86_64-windows-gnu %S/Inputs/associative-comdat-mingw-2.s -filetype=obj -o %t2.obj

# RUN: lld-link -lldmingw -entry:main %t1.obj %t2.obj -out:%t.gc.exe -verbose
# RUN: llvm-readobj --sections %t.gc.exe | FileCheck %s

# CHECK: Sections [
# CHECK:   Section {
# CHECK:     Number: 2
# CHECK-LABEL:     Name: .rdata (2E 72 64 61 74 61 00 00)
#             This is the critical check to show that only *one* definition of
#             .xdata$foo was retained. This *must* be 0x24 (0x4 for the .xdata
#             section and 0x20 for the .ctors/.dtors headers/ends).
#             Make sure that no other .xdata sections get included, which would
#             increase the size here.
# CHECK-NEXT:     VirtualSize: 0x24

        .text
        .def            main;
        .scl            2;
        .type           32;
        .endef
        .globl          main
        .p2align        4, 0x90
main:
        call            foo
        retq

# Defines .text$foo (which has a leader symbol and is referenced like
# normally), and .xdata$foo (which lacks a leader symbol, which normally
# would be declared associative to the symbol foo).
# .xdata$foo should be implicitly treated as associative to foo and brought
# in, while .xdata$bar, implicitly associative to bar, not included, and
# .xdata$baz not included since there's no symbol baz.

# GNU binutils ld doesn't do this at all, but always includes all .xdata/.pdata
# comdat sections, even if --gc-sections is used.

        .section        .xdata$foo,"dr"
        .linkonce       discard
        .p2align        3
        .long           42

        .section        .xdata$bar,"dr"
        .linkonce       discard
        .p2align        3
        .long           43

        .section        .xdata$baz,"dr"
        .linkonce       discard
        .p2align        3
        .long           44

        .def            foo;
        .scl            2;
        .type           32;
        .endef
        .section        .text$foo,"xr",discard,foo
        .globl          foo
        .p2align        4
foo:
        ret

        .def            bar;
        .scl            2;
        .type           32;
        .endef
        .section        .text$bar,"xr",discard,bar
        .globl          bar
        .p2align        4
bar:
        ret
