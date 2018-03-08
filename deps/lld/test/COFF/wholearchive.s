# REQEUIRES: x86

# RUN: yaml2obj < %p/Inputs/export.yaml > %t.archive.obj
# RUN: llvm-ar rcs %t.archive.lib %t.archive.obj
# RUN: llvm-mc -triple=x86_64-windows-msvc %s -filetype=obj -o %t.main.obj

# RUN: lld-link -dll -out:%t.dll -entry:main %t.main.obj -wholearchive:%t.archive.lib -implib:%t.lib
# RUN: llvm-readobj %t.lib | FileCheck %s -check-prefix CHECK-IMPLIB

# RUN: lld-link -dll -out:%t.dll -entry:main %t.main.obj -wholearchive %t.archive.lib -implib:%t.lib
# RUN: llvm-readobj %t.lib | FileCheck %s -check-prefix CHECK-IMPLIB

# CHECK-IMPLIB: Symbol: __imp_exportfn3
# CHECK-IMPLIB: Symbol: exportfn3

.global main
.text
main:
  ret
