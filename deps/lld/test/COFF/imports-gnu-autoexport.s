# REQUIRES: x86
#
# RUN: llvm-mc -triple=x86_64-windows-gnu %p/Inputs/gnu-implib-head.s -filetype=obj -o %t-dabcdh.o
# RUN: llvm-mc -triple=x86_64-windows-gnu %p/Inputs/gnu-implib-func.s -filetype=obj -o %t-dabcds00000.o
# RUN: llvm-mc -triple=x86_64-windows-gnu %p/Inputs/gnu-implib-tail.s -filetype=obj -o %t-dabcdt.o
# RUN: rm -f %t-implib.a
# RUN: llvm-ar rcs %t-implib.a %t-dabcdh.o %t-dabcds00000.o %t-dabcdt.o
# RUN: lld-link -lldmingw -dll -out:%t.dll -entry:main -subsystem:console \
# RUN:   %p/Inputs/hello64.obj %p/Inputs/std64.lib %t-implib.a -include:func
# RUN: llvm-readobj --coff-exports %t.dll | FileCheck -check-prefix=EXPORT %s

# Check that only the single normal symbol was exported, none of the symbols
# from the import library.

EXPORT:      Export {
EXPORT-NEXT:   Ordinal: 0
EXPORT-NEXT:   Name:
EXPORT-NEXT:   RVA: 0x0
EXPORT-NEXT: }
EXPORT-NEXT: Export {
EXPORT-NEXT:   Ordinal: 1
EXPORT-NEXT:   Name: main
EXPORT-NEXT:   RVA: 0x1010
EXPORT-NEXT: }
EXPORT-NEXT-EMPTY:
