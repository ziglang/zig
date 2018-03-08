# RUN: llvm-mc -triple=x86_64-windows-msvc %s -filetype=obj -o %t.obj
# RUN: lld-link -entry:main %t.obj -out:%t.exe -verbose 2>&1 | FileCheck %s

# CHECK: Selected internal
# CHECK:   Removed f2

.section .text,"xr",one_only,internal
internal:
.globl main
main:
call f2
ret

.section .text,"xr",one_only,f2
.globl f2
f2:
call main
ret
