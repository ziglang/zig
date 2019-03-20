# REQUIRES: aarch64

# RUN: echo -e ".global variable\n.global DllMainCRTStartup\n.text\nDllMainCRTStartup:\nret\n.data\nvariable:\n.long 42" > %t-lib.s
# RUN: llvm-mc -triple=aarch64-windows-gnu %t-lib.s -filetype=obj -o %t-lib.obj
# RUN: lld-link -out:%t-lib.dll -dll -entry:DllMainCRTStartup %t-lib.obj -lldmingw -implib:%t-lib.lib

# RUN: llvm-mc -triple=aarch64-windows-gnu %s -filetype=obj -o %t.obj
# RUN: not lld-link -lldmingw -out:%t.exe -entry:main %t.obj %t-lib.lib 2>&1 | FileCheck %s

# CHECK: error: unable to automatically import from variable with relocation type IMAGE_REL_ARM64_PAGEBASE_REL21
# CHECK: error: unable to automatically import from variable with relocation type IMAGE_REL_ARM64_PAGEOFFSET_12L

    .global main
    .text
main:
    adrp x0, variable
    ldr  w0, [x0, :lo12:variable]
    ret
