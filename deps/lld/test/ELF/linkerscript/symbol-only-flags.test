# REQUIRES: x86
# RUN: echo '.section .tbss,"awT",@nobits; .quad 0' \
# RUN:   | llvm-mc -filetype=obj -triple=x86_64-unknown-linux - -o %t.o
# RUN: ld.lld -o %t --script %s %t.o
# RUN: llvm-readobj -s %t | FileCheck %s

SECTIONS {
  . = SIZEOF_HEADERS;
  .tbss : { *(.tbss) }
  .foo : { bar = .; }
}

## Check .foo does not get SHF_TLS flag.
# CHECK:     Section {
# CHECK:       Index:
# CHECK:       Name: .foo
# CHECK-NEXT:  Type: SHT_NOBITS
# CHECK-NEXT:  Flags [
# CHECK-NEXT:    SHF_ALLOC
# CHECK-NEXT:    SHF_WRITE
# CHECK-NEXT:  ]
