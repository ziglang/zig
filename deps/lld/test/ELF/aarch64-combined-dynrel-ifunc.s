// REQUIRES: AArch64
// RUN: llvm-mc -filetype=obj -triple=aarch64-linux-gnu %p/Inputs/shared.s -o %t-lib.o
// RUN: llvm-mc -filetype=obj -triple=aarch64-linux-gnu %s -o %t.o
// RUN: ld.lld %t-lib.o --shared -o %t.so
// RUN: echo "SECTIONS { \
// RUN:         .text : { *(.text) } \
// RUN:         .rela.dyn : { *(.rela.dyn) *(.rela.plt) } \
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
// relocs. In the AArch64 case irelative relocations count as PLT relocs.

.text
.globl indirect
.type indirect,@gnu_indirect_function
indirect:
 ret

.globl bar // from Inputs/shared.s

.text
.globl _start
.type _start,@function
main:
 bl indirect
 bl bar
 adrp x8, :got:indirect
 ldr  x8, [x8, :got_lo12:indirect]
 adrp    x8, :got:bar
 ldr     x8, [x8, :got_lo12:bar]
 ret

// CHECK:     Name: .rela.dyn
// CHECK-NEXT:     Type: SHT_RELA
// CHECK-NEXT:     Flags [
// CHECK-NEXT:       SHF_ALLOC
// CHECK-NEXT:     ]
// CHECK-NEXT:     Address:
// CHECK-NEXT:     Offset:
// CHECK-NEXT:     Size: 72

// CHECK:      0x0000000000000008 RELASZ               72
// CHECK:      0x0000000000000002 PLTRELSZ             48
