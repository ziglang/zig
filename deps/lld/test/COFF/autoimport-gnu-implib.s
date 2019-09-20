# REQUIRES: x86

# RUN: llvm-mc -triple=x86_64-windows-gnu %p/Inputs/gnu-implib-head.s -filetype=obj -o %t-dabcdh.o
# RUN: llvm-mc -triple=x86_64-windows-gnu %p/Inputs/gnu-implib-data.s -filetype=obj -o %t-dabcds00000.o
# RUN: llvm-mc -triple=x86_64-windows-gnu %p/Inputs/gnu-implib-tail.s -filetype=obj -o %t-dabcdt.o
# RUN: rm -f %t-implib.a
# RUN: llvm-ar rcs %t-implib.a %t-dabcdh.o %t-dabcds00000.o %t-dabcdt.o

# RUN: llvm-mc -triple=x86_64-windows-gnu %s -filetype=obj -o %t.obj
# RUN: lld-link -lldmingw -debug:symtab -out:%t.exe -entry:main %t.obj %t-implib.a -verbose

# RUN: llvm-readobj --coff-imports %t.exe | FileCheck -check-prefix=IMPORTS %s
# RUN: llvm-nm %t.exe | FileCheck -check-prefix=SYMBOLS %s

# IMPORTS: Import {
# IMPORTS-NEXT: Name: foo.dll
# IMPORTS-NEXT: ImportLookupTableRVA:
# IMPORTS-NEXT: ImportAddressTableRVA:
# IMPORTS-NEXT: Symbol: data (0)
# IMPORTS-NEXT: }

# Check that the automatically imported symbol "data" is not listed in
# the symbol table.
# SYMBOLS-NOT: {{ }}data

    .global main
    .text
main:
    movl data(%rip), %eax
    ret
    .data
