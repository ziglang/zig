# REQUIRES: x86

# RUN: llvm-mc -triple=i686-windows-gnu %s -filetype=obj -o %t.main.o
# RUN: llvm-mc -filetype=obj -triple=i686-windows-gnu \
# RUN:   %p/Inputs/eh_frame_terminator-crtend.s -o %t.crtend.o

# RUN: lld-link -lldmingw -entry:main %t.main.o %t.crtend.o -out:%t.exe
# RUN: llvm-objdump -s %t.exe | FileCheck %s

# Check that the contents of .eh_frame$foo was placed before .eh_frame from
# crtend.o, even if the former had a section name suffix.

# CHECK: Contents of section .eh_fram:
# CHECK:  403000 4203

        .text
        .def            _main;
        .scl            2;
        .type           32;
        .endef
        .globl          _main
        .p2align        4, 0x90
_main:
        call            _foo
        ret

        .section        .eh_frame$foo,"dr"
        .linkonce       discard
        .byte           0x42

        .def            _foo;
        .scl            2;
        .type           32;
        .endef
        .section        .text$foo,"xr",discard,foo
        .globl          _foo
        .p2align        4
_foo:
        ret
