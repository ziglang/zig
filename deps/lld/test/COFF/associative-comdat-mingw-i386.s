# REQUIRES: x86

# RUN: llvm-mc -triple=i686-windows-gnu %s -filetype=obj -o %t.obj

# RUN: lld-link -lldmingw -entry:main %t.obj -out:%t.exe
# RUN: llvm-objdump -s %t.exe | FileCheck %s

# Check that the .eh_frame comdat was included, even if it had no symbols,
# due to associativity with the symbol _foo.

# CHECK: Contents of section .eh_fram:
# CHECK:  403000 42

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
