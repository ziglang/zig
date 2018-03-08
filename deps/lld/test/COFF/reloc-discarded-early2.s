# RUN: llvm-mc -triple=x86_64-windows-msvc -filetype=obj -o %t.obj %s
# RUN: not lld-link -entry:__ImageBase -subsystem:console %t.obj 2>&1 | FileCheck %s

.text
# CHECK: error: relocation against symbol in discarded section: .drectve
.quad .Ldrectve

.section .drectve
.Ldrectve:
