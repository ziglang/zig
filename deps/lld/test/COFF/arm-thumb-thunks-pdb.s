// REQUIRES: arm
// RUN: llvm-mc -filetype=obj -triple=thumbv7-windows %s -o %t.obj
// RUN: lld-link -entry:main -subsystem:console %t.obj -out:%t.exe -debug -pdb:%t.pdb -verbose 2>&1 | FileCheck %s --check-prefix=VERBOSE

// VERBOSE: Added 1 thunks with margin {{.*}} in {{.*}} passes

    .syntax unified
    .globl main
    .globl func1
    .text
main:
    bne func1
    bx lr
    .section .text$a, "xr"
    .space 0x100000
    .section .text$b, "xr"
func1:
    bx lr
