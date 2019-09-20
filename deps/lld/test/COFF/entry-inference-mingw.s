# REQUIRES: x86
# RUN: llvm-mc -triple=x86_64-windows-gnu %s -filetype=obj -o %t.o

# RUN: lld-link -lldmingw %t.o -out:%t-default.exe 2>&1 | FileCheck -allow-empty -check-prefix=LINK %s
# RUN: lld-link -lldmingw %t.o -out:%t-cui.exe -subsystem:console 2>&1 | FileCheck -allow-empty -check-prefix=LINK %s
# RUN: lld-link -lldmingw %t.o -out:%t-gui.exe -subsystem:windows 2>&1 | FileCheck -allow-empty -check-prefix=LINK %s

# RUN: llvm-readobj --file-headers %t-default.exe | FileCheck -check-prefix=CUI %s
# RUN: llvm-readobj --file-headers %t-cui.exe | FileCheck -check-prefix=CUI %s
# RUN: llvm-readobj --file-headers %t-gui.exe | FileCheck -check-prefix=GUI %s

# Check that this doesn't print any warnings.
# LINK-NOT: found both wmain and main

# CUI: AddressOfEntryPoint: 0x1001
# CUI: Subsystem: IMAGE_SUBSYSTEM_WINDOWS_CUI (0x3)

# GUI: AddressOfEntryPoint: 0x1002
# GUI: Subsystem: IMAGE_SUBSYSTEM_WINDOWS_GUI (0x2)


        .text
        .globl mainCRTStartup
        .globl WinMainCRTStartup
# MinGW only uses the entry points above, these other ones aren't
# used as entry.
        .globl main
        .globl wmain
        .globl wmainCRTStartup
        .globl wWinMainCRTStartup
foo:
        ret
mainCRTStartup:
        ret
WinMainCRTStartup:
        ret
main:
        ret
wmain:
        ret
wmainCRTStartup:
        ret
wWinMainCRTStartup:
        ret
