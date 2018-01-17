# REQUIRES: arm
# RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %s -o %t.o
# RUN: echo "SECTIONS { . = SIZEOF_HEADERS;    \
# RUN:         .ARM.exidx : { *(.ARM.exidx*) } \
# RUN:         .foo : { _foo = 0; } }" > %t.script
# RUN: ld.lld -T %t.script %t.o -shared -o %t.so
# RUN: llvm-readobj -s %t.so | FileCheck %s

# CHECK:      Section {
# CHECK:        Index:
# CHECK:        Name: .foo
# CHECK-NEXT:   Type: SHT_NOBITS
# CHECK-NEXT:   Flags [
# CHECK-NEXT:     SHF_ALLOC
# CHECK-NEXT:   ]

.fnstart
.cantunwind
.fnend
