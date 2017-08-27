# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=i686-windows-msvc %s -o %t.obj
# RUN: echo -e "LIBRARY foo\nEXPORTS\n  stdcall" > %t.def
# RUN: lld-link -entry:dllmain -dll -def:%t.def %t.obj -out:%t.dll -implib:%t.lib
# RUN: llvm-readobj %t.lib | FileCheck %s
# CHECK: Name type: undecorate
# CHECK: __imp__stdcall@8
# CHECK: _stdcall@8

        .def     _stdcall@8;
        .scl    2;
        .type   32;
        .endef
        .globl  _stdcall@8
_stdcall@8:
        movl    8(%esp), %eax
        addl    4(%esp), %eax
        retl    $8

        .def     _dllmain;
        .scl    2;
        .type   32;
        .endef
        .globl  _dllmain
_dllmain:
        retl

