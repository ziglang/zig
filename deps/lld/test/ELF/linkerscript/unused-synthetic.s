# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: echo "SECTIONS { \
# RUN:    .got  : { *(.got) *(.got) } \
# RUN:    .plt  : { *(.plt) } \
# RUN:    .text : { *(.text) } \
# RUN:  }" > %t.script
# RUN: ld.lld -shared -o %t.so --script %t.script %t.o

# RUN: llvm-readelf -S %t.so | FileCheck %s
# CHECK-NOT:  .got
# CHECK-NOT:  .plt
# CHECK:      .dynsym
# CHECK:      .text

# Test that the size of a removed unused synthetic input section is not added
# to the output section size. Adding a symbol assignment prevents removal of
# the output section, but does not cause the section size to be recomputed.
# RUN: echo "SECTIONS { \
# RUN:    .got.plt : { a_sym = .; *(.got.plt) } \
# RUN:  }" > %t2.script
# RUN: ld.lld -shared -o %t2.so --script %t2.script %t.o
# RUN: llvm-objdump -section-headers %t2.so | FileCheck %s --check-prefix=CHECK2
# CHECK2: .got.plt 00000000

.global _start
_start:
  nop
