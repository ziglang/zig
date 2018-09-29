# REQUIRES: x86
# RUN: llvm-mc %s -filetype=obj -triple=x86_64-windows-msvc -o %t.obj
# RUN: not lld-link -entry:main -nodefaultlib %t.obj -out:%t.exe 2>&1 | FileCheck %s

# secrel relocations against absolute symbols are errors.

# CHECK: SECREL relocation cannot be applied to absolute symbols

.text
.global main
main:
ret

.section .rdata,"dr"
.secrel32 __guard_fids_table
