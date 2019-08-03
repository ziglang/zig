# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=i686-windows-msvc %s -o %t.obj

# RUN: lld-link -safeseh:no -entry:dllmain -dll %t.obj -out:%t.dll -implib:%t.lib
# RUN: llvm-readobj %t.lib | FileCheck -check-prefix DECORATED-IMPLIB %s
# RUN: llvm-readobj --coff-exports %t.dll | FileCheck -check-prefix DECORATED-EXPORTS %s

# DECORATED-IMPLIB: Name type: name
# DECORATED-IMPLIB-NEXT: __imp_@fastcall@8
# DECORATED-IMPLIB-NEXT: @fastcall@8
# DECORATED-IMPLIB: Name type: name
# DECORATED-IMPLIB-NEXT: __imp__stdcall@8
# DECORATED-IMPLIB-NEXT: _stdcall@8
# DECORATED-IMPLIB: Name type: noprefix
# DECORATED-IMPLIB-NEXT: __imp___underscored
# DECORATED-IMPLIB-NEXT: __underscored
# DECORATED-IMPLIB: Name type: name
# DECORATED-IMPLIB-NEXT: __imp_vectorcall@@8
# DECORATED-IMPLIB-NEXT: vectorcall@@8

# DECORATED-EXPORTS: Name: @fastcall@8
# DECORATED-EXPORTS: Name: _stdcall@8
# DECORATED-EXPORTS: Name: _underscored
# DECORATED-EXPORTS: Name: vectorcall@@8

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

.section .drectve
.ascii "-export:__underscored -export:_stdcall@8 -export:@fastcall@8 -export:vectorcall@@8"
