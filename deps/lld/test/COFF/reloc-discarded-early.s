# REQUIRES: x86
# RUN: llvm-mc -triple=x86_64-windows-msvc -filetype=obj -o %t.obj %s
# RUN: lld-link -entry:__ImageBase -subsystem:console -debug %t.obj

.section .debug_info,"dr"
.quad .Ldrectve

.section .drectve
.Ldrectve:
