// REQUIRES: arm
// RUN: llvm-mc -filetype=obj  -arm-add-build-attributes -triple=armv7a-linux-gnueabihf %p/Inputs/arm-shared.s -o %t-lib.o
// RUN: llvm-mc -filetype=obj -arm-add-build-attributes -triple=armv7a-linux-gnueabihf %s -o %t.o
// RUN: ld.lld %t-lib.o --shared -o %t.so
// RUN: echo "SECTIONS { \
// RUN:         .text : { *(.text) } \
// RUN:         .rela.dyn : { *(.rel.dyn) *(.rel.plt) } \
// RUN: } " > %t.script
// RUN: ld.lld %t.o -o %t.axf %t.so --script %t.script
// RUN: llvm-readobj --section-headers --dynamic-table %t.axf | FileCheck %s

// The linker script above combines the .rela.dyn and .rela.plt into a single
// table. ELF is clear that the DT_PLTRELSZ should match the subset of
// relocations that is associated with the PLT. It is less clear about what
// the value of DT_RELASZ should be. ELF implies that it should be the size
// of the single table so that DT_RELASZ includes DT_PLTRELSZ. The loader in
// glibc permits this as long as .rela.plt comes after .rela.dyn in the
// combined table. In the ARM case irelative relocations do not count as PLT
// relocs.

.text
.globl indirect
.type indirect,%gnu_indirect_function
indirect:
 bx lr

.globl bar2 // from Inputs/arm-shared.s

.text
.globl _start
.type _start,%function
main:
 bl indirect
 bl bar2
 .word indirect(got)
 .word bar2(got)
 bx lr

// CHECK:     Name: .rela.dyn
// CHECK-NEXT:     Type: SHT_REL
// CHECK-NEXT:     Flags [
// CHECK-NEXT:       SHF_ALLOC
// CHECK-NEXT:     ]
// CHECK-NEXT:     Address:
// CHECK-NEXT:     Offset:
// CHECK-NEXT:     Size: 24

// CHECK: 0x00000012 RELSZ                24 (bytes)
// CHECK: 0x00000002 PLTRELSZ             8 (bytes)
