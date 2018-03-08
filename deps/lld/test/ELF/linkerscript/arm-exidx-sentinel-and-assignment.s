# REQUIRES: arm
# RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %s -o %t.o
# RUN: echo "SECTIONS {                                        \
# RUN:         .ARM.exidx 0x1000 : { *(.ARM.exidx*) foo = .; } \
# RUN:         .text      0x2000 : { *(.text*) }               \
# RUN:       }" > %t.script
## We used to crash if the last output section command for .ARM.exidx
## was anything but an input section description.
# RUN: ld.lld --no-merge-exidx-entries -T %t.script %t.o -shared -o %t.so
# RUN: llvm-objdump -s -triple=armv7a-none-linux-gnueabi %t.so | FileCheck %s
# RUN: llvm-readobj -s -t %t.so | FileCheck %s --check-prefix=SYMBOL

 .syntax unified
 .text
 .global _start
_start:
 .fnstart
 .cantunwind
 bx lr
 .fnend

# CHECK: Contents of section .ARM.exidx:
# 1000 + 1000 = 0x2000 = _start
# 1008 + 0ffc = 0x2004 = _start + sizeof(_start)
# CHECK-NEXT: 1000 00100000 01000000 fc0f0000 01000000

# SYMBOL:       Section {
# SYMBOL:         Name: .ARM.exidx
# SYMBOL-NEXT:    Type: SHT_ARM_EXIDX
# SYMBOL-NEXT:    Flags [
# SYMBOL-NEXT:      SHF_ALLOC
# SYMBOL-NEXT:      SHF_LINK_ORDER
# SYMBOL-NEXT:    ]
# SYMBOL-NEXT:    Address: 0x1000
# SYMBOL-NEXT:    Offset:
# SYMBOL-NEXT:    Size: 16

# Symbol 'foo' is expected to point at the end of the section.
# SYMBOL:       Symbol {
# SYMBOL:         Name: foo
# SYMBOL-NEXT:    Value: 0x1010
