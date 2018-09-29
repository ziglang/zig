# REQUIRES: x86
# RUN: llvm-mc -triple=x86_64-windows-msvc -filetype=obj -o %t.obj %s
# RUN: lld-link %t.obj /out:%t.exe /entry:main /subsystem:console
# RUN: llvm-objdump -s %t.exe | FileCheck %s

# CHECK: Contents of section .text:
.globl main
main:
# CHECK-NEXT: 140001000 00200040 01000000 01200040 01000000
.8byte "??_"
.8byte "??_7"
# CHECK-NEXT: 140001010 01200040 01000000
.8byte "??_7a"

.section .rdata,"dr",discard,"??_"
.globl "??_"
"??_":
.byte 42

.section .rdata,"dr",discard,"??_7"
.globl "??_7"
"??_7":
.byte 42

.section .rdata,"dr",discard,"??_7a"
.globl "??_7a"
"??_7a":
.byte 42
