# REQUIRES: arm

# RUN: echo -e ".global variable\n.global DllMainCRTStartup\n.thumb\n.text\nDllMainCRTStartup:\nbx lr\n.data\nvariable:\n.long 42" > %t-lib.s
# RUN: llvm-mc -triple=armv7-windows-gnu %t-lib.s -filetype=obj -o %t-lib.obj
# RUN: lld-link -out:%t-lib.dll -dll -entry:DllMainCRTStartup %t-lib.obj -lldmingw -implib:%t-lib.lib

# RUN: llvm-mc -triple=armv7-windows-gnu %s -filetype=obj -o %t.obj
# RUN: lld-link -lldmingw -out:%t.exe -entry:main %t.obj %t-lib.lib -verbose

# RUN: llvm-readobj --coff-imports %t.exe | FileCheck -check-prefix=IMPORTS %s
# RUN: llvm-objdump -s %t.exe | FileCheck -check-prefix=CONTENTS %s

# IMPORTS: Import {
# IMPORTS-NEXT: Name: autoimport-arm-data.s.tmp-lib.dll
# IMPORTS-NEXT: ImportLookupTableRVA: 0x2050
# IMPORTS-NEXT: ImportAddressTableRVA: 0x2058
# IMPORTS-NEXT: Symbol: variable (0)
# IMPORTS-NEXT: }

# Runtime pseudo reloc list header consisting of 0x0, 0x0, 0x1.
# First runtime pseudo reloc, with import from 0x2058,
# applied at 0x3000, with a size of 32 bits.
# CONTENTS: Contents of section .rdata:
# CONTENTS:  402000 00000000 00000000 01000000 58200000
# CONTENTS:  402010 00300000 20000000
# ptr: pointing at the IAT RVA at 0x2058
# relocs: pointing at the runtime pseudo reloc list at
# 0x2000 - 0x2018.
# CONTENTS: Contents of section .data:
# CONTENTS:  403000 58204000 00204000 18204000

    .global main
    .text
    .thumb
main:
    bx lr
    .data
ptr:
    .long variable
relocs:
    .long __RUNTIME_PSEUDO_RELOC_LIST__
    .long __RUNTIME_PSEUDO_RELOC_LIST_END__
