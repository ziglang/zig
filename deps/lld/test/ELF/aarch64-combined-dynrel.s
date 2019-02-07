// REQUIRES: AArch64
// RUN: llvm-mc --triple=aarch64-linux-gnu -filetype=obj -o %t.o %s
// RUN: echo "SECTIONS { \
// RUN:         .text : { *(.text) } \
// RUN:         .rela.dyn : { *(.rela.dyn) *(.rela.plt) } \
// RUN: } " > %t.script
// RUN: ld.lld %t.o -o %t.so --shared --script %t.script
// RUN: llvm-readobj --section-headers --dynamic-table %t.so | FileCheck %s

// The linker script above combines the .rela.dyn and .rela.plt into a single
// table. ELF is clear that the DT_PLTRELSZ should match the subset of
// relocations that is associated with the PLT. It is less clear about what
// the value of DT_RELASZ should be. ELF implies that it should be the size
// of the single table so that DT_RELASZ includes DT_PLTRELSZ. The loader in
// glibc permits this as long as .rela.plt comes after .rela.dyn in the
// combined table.
 .text
 .globl func
 .type func, %function
 .globl foo
 .type foo, %object

 .globl _start
 .type _start, %function
_start:
 bl func
 adrp    x8, :got:foo
 ldr     x8, [x8, :got_lo12:foo]
 ret

// CHECK:     Name: .rela.dyn
// CHECK-NEXT:         Type: SHT_RELA
// CHECK-NEXT:     Flags [
// CHECK-NEXT:       SHF_ALLOC
// CHECK-NEXT:     ]
// CHECK-NEXT:     Address:
// CHECK-NEXT:     Offset:
// CHECK-NEXT:     Size: 48

// CHECK:  0x0000000000000008 RELASZ               48
// CHECK:  0x0000000000000002 PLTRELSZ             24
