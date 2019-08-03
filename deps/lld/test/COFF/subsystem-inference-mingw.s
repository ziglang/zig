# REQUIRES: x86
# RUN: llvm-mc -triple=x86_64-windows-gnu %s -filetype=obj -o %t.o

# RUN: lld-link -lldmingw %t.o -out:%t.exe
# RUN: llvm-readobj --file-headers %t.exe | FileCheck %s

# CHECK: AddressOfEntryPoint: 0x1001
# CHECK: Subsystem: IMAGE_SUBSYSTEM_WINDOWS_CUI (0x3)

        .text
        .globl foo
        .globl mainCRTStartup
foo:
        ret
mainCRTStartup:
        call foo
        ret
