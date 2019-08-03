# REQUIRES: x86
#
# RUN: llvm-mc -triple=x86_64-windows-gnu %s -filetype=obj -o %t.obj
# RUN: lld-link -out:%t.exe -entry:main -subsystem:console %t.obj
# RUN: llvm-objdump -s %t.exe | FileCheck -check-prefix=DUMP %s
# RUN: llvm-readobj --file-headers %t.exe | FileCheck -check-prefix=DIRECTORY %s

        .text
        .global main
main:
        ret

# Check that no .idata (.rdata) entries were added, no null terminator
# for the import descriptor table.
# DUMP: Contents of section .text:
# DUMP-NEXT: 140001000 c3
# DUMP-NEXT-EMPTY:

# DIRECTORY: ImportTableRVA: 0x0
# DIRECTORY: ImportTableSize: 0x0
