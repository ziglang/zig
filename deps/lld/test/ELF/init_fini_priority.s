// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
// RUN: llvm-objdump -section-headers %t | FileCheck %s --check-prefix=OBJ
// RUN: ld.lld %t -o %t.exe
// RUN: llvm-objdump -s %t.exe | FileCheck %s

// OBJ:       3 .init_array
// OBJ-NEXT:  4 .init_array.100
// OBJ-NEXT:  5 .init_array.5
// OBJ-NEXT:  6 .init_array
// OBJ-NEXT:  7 .init_array
// OBJ-NEXT:  8 .fini_array
// OBJ-NEXT:  9 .fini_array.100
// OBJ-NEXT: 10 .fini_array.5
// OBJ-NEXT: 11 .fini_array
// OBJ-NEXT: 12 .fini_array

.globl _start
_start:
  nop

.section .init_array, "aw", @init_array, unique, 0
  .align 8
  .byte 1
.section .init_array.100, "aw", @init_array
  .long 2
.section .init_array.5, "aw", @init_array
  .byte 3
.section .init_array, "aw", @init_array, unique, 1
  .byte 4
.section .init_array, "aw", @init_array, unique, 2
  .byte 5

.section .fini_array, "aw", @fini_array, unique, 0
  .align 8
  .byte 0x11
.section .fini_array.100, "aw", @fini_array
  .long 0x12
.section .fini_array.5, "aw", @fini_array
  .byte 0x13
.section .fini_array, "aw", @fini_array, unique, 1
  .byte 0x14
.section .fini_array, "aw", @fini_array, unique, 2
  .byte 0x15

// CHECK:      Contents of section .init_array:
// CHECK-NEXT: 03020000 00000000 010405
// CHECK:      Contents of section .fini_array:
// CHECK-NEXT: 13120000 00000000 111415
