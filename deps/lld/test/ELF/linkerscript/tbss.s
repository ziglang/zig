# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: echo "SECTIONS { \
# RUN:   . = SIZEOF_HEADERS; \
# RUN:   .text : { *(.text) } \
# RUN:   foo : { *(foo) } \
# RUN:   bar : { *(bar) } \
# RUN: }" > %t.script
# RUN: ld.lld -T %t.script %t.o -o %t
# RUN: llvm-readobj -s %t | FileCheck %s

# test that a tbss section doesn't use address space.

# CHECK:        Name: foo
# CHECK-NEXT:   Type: SHT_NOBITS
# CHECK-NEXT:   Flags [
# CHECK-NEXT:     SHF_ALLOC
# CHECK-NEXT:     SHF_TLS
# CHECK-NEXT:     SHF_WRITE
# CHECK-NEXT:   ]
# CHECK-NEXT:   Address: 0x[[ADDR:.*]]
# CHECK-NEXT:   Offset: 0x[[ADDR]]
# CHECK-NEXT:   Size: 4
# CHECK-NEXT:   Link: 0
# CHECK-NEXT:   Info: 0
# CHECK-NEXT:   AddressAlignment: 1
# CHECK-NEXT:   EntrySize: 0
# CHECK-NEXT: }
# CHECK-NEXT: Section {
# CHECK-NEXT:   Index:
# CHECK-NEXT:   Name: bar
# CHECK-NEXT:   Type: SHT_PROGBITS
# CHECK-NEXT:   Flags [
# CHECK-NEXT:     SHF_ALLOC
# CHECK-NEXT:     SHF_WRITE
# CHECK-NEXT:   ]
# CHECK-NEXT:   Address: 0x[[ADDR]]

        .section foo,"awT",@nobits
        .long   0
        .section bar, "aw"
        .long 0
