# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t

# RUN: echo "SECTIONS { . = 0x10000000; .text : {*(.text.*)} }" > %t.script
# RUN: ld.lld -o %t1 --script %t.script %t
# RUN: llvm-readobj -program-headers %t1 | FileCheck %s
# CHECK:      ProgramHeaders [
# CHECK-NEXT:  ProgramHeader {
# CHECK-NEXT:    Type: PT_PHDR (0x6)
# CHECK-NEXT:    Offset: 0x40
# CHECK-NEXT:    VirtualAddress: 0xFFFF040

.global _start
_start:
 nop
