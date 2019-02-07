# REQUIRES: arm

# RUN: echo -e ".global variable\n.global DllMainCRTStartup\n.thumb\n.text\nDllMainCRTStartup:\nbx lr\n.data\nvariable:\n.long 42" > %t-lib.s
# RUN: llvm-mc -triple=armv7-windows-gnu %t-lib.s -filetype=obj -o %t-lib.obj
# RUN: lld-link -out:%t-lib.dll -dll -entry:DllMainCRTStartup %t-lib.obj -lldmingw -implib:%t-lib.lib

# RUN: llvm-mc -triple=armv7-windows-gnu %s -filetype=obj -o %t.obj
# RUN: not lld-link -lldmingw -out:%t.exe -entry:main %t.obj %t-lib.lib 2>&1 | FileCheck %s

# CHECK: error: unable to automatically import from variable with relocation type IMAGE_REL_ARM_MOV32T

    .global main
    .text
    .thumb
main:
    movw r0, :lower16:variable
    movt r0, :upper16:variable
    ldr  r0, [r0]
    bx   lr
