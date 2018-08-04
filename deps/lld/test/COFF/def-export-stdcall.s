# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=i686-windows-msvc %s -o %t.obj
# RUN: echo -e "LIBRARY foo\nEXPORTS\n  stdcall\n  fastcall\n  vectorcall\n  _underscored" > %t.def
# RUN: lld-link -entry:dllmain -dll -def:%t.def %t.obj -out:%t.dll -implib:%t.lib
# RUN: llvm-readobj %t.lib | FileCheck -check-prefix UNDECORATED-IMPLIB %s
# RUN: llvm-readobj -coff-exports %t.dll | FileCheck -check-prefix UNDECORATED-EXPORTS %s

# UNDECORATED-IMPLIB: Name type: noprefix
# UNDECORATED-IMPLIB-NEXT: __imp___underscored
# UNDECORATED-IMPLIB-NEXT: __underscored
# UNDECORATED-IMPLIB: Name type: undecorate
# UNDECORATED-IMPLIB-NEXT: __imp_@fastcall@8
# UNDECORATED-IMPLIB-NEXT: fastcall@8
# UNDECORATED-IMPLIB: Name type: undecorate
# UNDECORATED-IMPLIB-NEXT: __imp__stdcall@8
# UNDECORATED-IMPLIB-NEXT: _stdcall@8
# UNDECORATED-IMPLIB: Name type: undecorate
# UNDECORATED-IMPLIB-NEXT: __imp_vectorcall@@8
# UNDECORATED-IMPLIB-NEXT: vectorcall@@8

# UNDECORATED-EXPORTS: Name: _underscored
# UNDECORATED-EXPORTS: Name: fastcall
# UNDECORATED-EXPORTS: Name: stdcall
# UNDECORATED-EXPORTS: Name: vectorcall


# RUN: echo -e "LIBRARY foo\nEXPORTS\n  _stdcall@8\n  @fastcall@8\n  vectorcall@@8" > %t.def
# RUN: lld-link -entry:dllmain -dll -def:%t.def %t.obj -out:%t.dll -implib:%t.lib
# RUN: llvm-readobj %t.lib | FileCheck -check-prefix DECORATED-IMPLIB %s
# RUN: llvm-readobj -coff-exports %t.dll | FileCheck -check-prefix DECORATED-EXPORTS %s

# DECORATED-IMPLIB: Name type: name
# DECORATED-IMPLIB-NEXT: __imp_@fastcall@8
# DECORATED-IMPLIB-NEXT: @fastcall@8
# DECORATED-IMPLIB: Name type: name
# DECORATED-IMPLIB-NEXT: __imp__stdcall@8
# DECORATED-IMPLIB-NEXT: _stdcall@8
# DECORATED-IMPLIB: Name type: name
# DECORATED-IMPLIB-NEXT: __imp_vectorcall@@8
# DECORATED-IMPLIB-NEXT: vectorcall@@8

# DECORATED-EXPORTS: Name: @fastcall@8
# DECORATED-EXPORTS: Name: _stdcall@8
# DECORATED-EXPORTS: Name: vectorcall@@8


# GNU tools don't support vectorcall at the moment, but test it for completeness.
# RUN: echo -e "LIBRARY foo\nEXPORTS\n  stdcall@8\n  @fastcall@8\n  vectorcall@@8" > %t.def
# RUN: lld-link -lldmingw -entry:dllmain -dll -def:%t.def %t.obj -out:%t.dll -implib:%t.lib
# RUN: llvm-readobj %t.lib | FileCheck -check-prefix DECORATED-MINGW-IMPLIB %s
# RUN: llvm-readobj -coff-exports %t.dll | FileCheck -check-prefix DECORATED-MINGW-EXPORTS %s

# DECORATED-MINGW-IMPLIB: Name type: name
# DECORATED-MINGW-IMPLIB-NEXT: __imp_@fastcall@8
# DECORATED-MINGW-IMPLIB-NEXT: fastcall@8
# DECORATED-MINGW-IMPLIB: Name type: noprefix
# DECORATED-MINGW-IMPLIB-NEXT: __imp__stdcall@8
# DECORATED-MINGW-IMPLIB-NEXT: _stdcall@8
# GNU tools don't support vectorcall, but this test is just to track that
# lld's behaviour remains consistent over time.
# DECORATED-MINGW-IMPLIB: Name type: name
# DECORATED-MINGW-IMPLIB-NEXT: __imp_vectorcall@@8
# DECORATED-MINGW-IMPLIB-NEXT: vectorcall@@8

# DECORATED-MINGW-EXPORTS: Name: @fastcall@8
# DECORATED-MINGW-EXPORTS: Name: stdcall@8
# DECORATED-MINGW-EXPORTS: Name: vectorcall@@8

# RUN: lld-link -lldmingw -kill-at -entry:dllmain -dll -def:%t.def %t.obj -out:%t.dll -implib:%t.lib
# RUN: llvm-readobj %t.lib | FileCheck -check-prefix MINGW-KILL-AT-IMPLIB %s
# RUN: llvm-readobj -coff-exports %t.dll | FileCheck -check-prefix MINGW-KILL-AT-EXPORTS %s

# RUN: lld-link -lldmingw -kill-at -entry:dllmain -dll %t.obj -out:%t.dll -implib:%t.lib
# RUN: llvm-readobj %t.lib | FileCheck -check-prefix MINGW-KILL-AT-IMPLIB %s
# RUN: llvm-readobj -coff-exports %t.dll | FileCheck -check-prefix MINGW-KILL-AT-EXPORTS %s

# MINGW-KILL-AT-IMPLIB: Name type: noprefix
# MINGW-KILL-AT-IMPLIB: __imp__fastcall
# MINGW-KILL-AT-IMPLIB-NEXT: _fastcall
# MINGW-KILL-AT-IMPLIB: Name type: noprefix
# MINGW-KILL-AT-IMPLIB-NEXT: __imp__stdcall
# MINGW-KILL-AT-IMPLIB-NEXT: _stdcall
# GNU tools don't support vectorcall, but this test is just to track that
# lld's behaviour remains consistent over time.
# MINGW-KILL-AT-IMPLIB: Name type: noprefix
# MINGW-KILL-AT-IMPLIB-NEXT: __imp__vectorcall
# MINGW-KILL-AT-IMPLIB-NEXT: _vectorcall

# MINGW-KILL-AT-EXPORTS: Name: fastcall
# MINGW-KILL-AT-EXPORTS: Name: stdcall
# MINGW-KILL-AT-EXPORTS: Name: vectorcall


        .def     _stdcall@8;
        .scl    2;
        .type   32;
        .endef
        .globl  _stdcall@8
        .globl  @fastcall@8
        .globl  vectorcall@@8
        .globl  __underscored
_stdcall@8:
        movl    8(%esp), %eax
        addl    4(%esp), %eax
        retl    $8
@fastcall@8:
        movl    8(%esp), %eax
        addl    4(%esp), %eax
        retl    $8
vectorcall@@8:
        movl    8(%esp), %eax
        addl    4(%esp), %eax
        retl    $8
__underscored:
        ret

        .def     _dllmain;
        .scl    2;
        .type   32;
        .endef
        .globl  _dllmain
_dllmain:
        retl

