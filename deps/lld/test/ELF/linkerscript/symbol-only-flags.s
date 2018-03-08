# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: echo "SECTIONS { . = SIZEOF_HEADERS; \
# RUN:         .tbss : { *(.tbss) }         \
# RUN:         .foo : { bar = .; } }" > %t.script
# RUN: ld.lld -o %t --script %t.script %t.o
# RUN: llvm-readobj -s %t | FileCheck %s

## Check .foo does not get SHF_TLS flag.
# CHECK:     Section {
# CHECK:       Index:
# CHECK:       Name: .foo
# CHECK-NEXT:  Type: SHT_NOBITS
# CHECK-NEXT:  Flags [
# CHECK-NEXT:    SHF_ALLOC
# CHECK-NEXT:    SHF_WRITE
# CHECK-NEXT:  ]

.section .tbss,"awT",@nobits
.quad 0
