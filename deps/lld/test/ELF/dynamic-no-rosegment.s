# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld -shared --no-rosegment -z rodynamic -o %t %t.o
# RUN: llvm-readobj -dynamic-table -s %t | FileCheck %s

# CHECK:      DynamicSection [ (7 entries)
# CHECK-NEXT:   Tag                Type                 Name/Value
# CHECK-NEXT:   0x0000000000000006 SYMTAB               0x120
# CHECK-NEXT:   0x000000000000000B SYMENT               24 (bytes)
# CHECK-NEXT:   0x0000000000000005 STRTAB               0x1D0
# CHECK-NEXT:   0x000000000000000A STRSZ                1 (bytes)
# CHECK-NEXT:   0x000000006FFFFEF5 GNU_HASH             0x138
# CHECK-NEXT:   0x0000000000000004 HASH                 0x150
# CHECK-NEXT:   0x0000000000000000 NULL                 0x0
# CHECK-NEXT: ]
