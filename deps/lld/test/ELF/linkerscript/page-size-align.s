# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o

# RUN: echo "SECTIONS { \
# RUN:         . = SIZEOF_HEADERS; \
# RUN:         .text : { *(.text) } \
# RUN:         . = ALIGN(CONSTANT(MAXPAGESIZE)); \
# RUN:         . = . + 0x3000; \
# RUN:         .dynamic : { *(.dynamic) } \
# RUN:       }" > %t.script

# RUN: ld.lld -T %t.script -z max-page-size=0x4000 %t.o -o %t.so -shared
# RUN: llvm-readobj -s %t.so | FileCheck %s

# CHECK:      Name: .dynamic
# CHECK-NEXT: Type: SHT_DYNAMIC
# CHECK-NEXT: Flags [
# CHECK-NEXT:   SHF_ALLOC
# CHECK-NEXT:   SHF_WRITE
# CHECK-NEXT: ]
# CHECK-NEXT: Address: 0x7000
# CHECK-NEXT: Offset: 0x3000
