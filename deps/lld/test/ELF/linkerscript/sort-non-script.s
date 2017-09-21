# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t

# RUN: echo "SECTIONS { foo : {*(foo)} }" > %t.script
# RUN: ld.lld -o %t1 --script %t.script %t -shared
# RUN: llvm-readobj -elf-output-style=GNU -s %t1 | FileCheck %s

# CHECK:      .text    {{.*}}   AX
# CHECK-NEXT: .dynsym  {{.*}}   A
# CHECK-NEXT: .hash    {{.*}}   A
# CHECK-NEXT: .dynstr  {{.*}}   A
# CHECK-NEXT: foo      {{.*}}  WA
# CHECK-NEXT: .dynamic {{.*}}  WA

.section foo, "aw"
.byte 0
