# REQUIRES: x86

# RUN: llvm-mc -triple=i686-windows-gnu %s -filetype=obj -o %t.obj

# RUN: lld-link -lldmingw -dll -out:%t.dll -entry:main %t.obj -implib:%t.lib
# RUN: llvm-readobj %t.lib | FileCheck %s

# CHECK: Symbol: __imp___underscoredFunc
# CHECK: Symbol: __underscoredFunc
# CHECK: Symbol: __imp__func
# CHECK: Symbol: _func

.global _main
.global _func
.global __underscoredFunc
.text
_main:
  ret
_func:
  ret
__underscoredFunc:
  ret
.section .drectve
.ascii "-export:func -export:_underscoredFunc"
