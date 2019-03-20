# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o

# RUN: echo "SECTIONS { foo : {*(foo)} }" > %t.script
# RUN: ld.lld --hash-style=sysv -o %t --script %t.script %t.o -shared
# RUN: llvm-readelf -S %t | FileCheck %s

# CHECK:      .dynsym  {{.*}}   A
# CHECK-NEXT: .hash    {{.*}}   A
# CHECK-NEXT: .dynstr  {{.*}}   A
# CHECK-NEXT: .text    {{.*}}   AX
# CHECK-NEXT: foo      {{.*}}  WA
# CHECK-NEXT: .dynamic {{.*}}  WA

.section foo, "aw"
.byte 0
