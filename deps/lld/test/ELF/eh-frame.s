// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t1.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %S/Inputs/eh-frame.s -o %t2.o
// RUN: ld.lld %t1.o %t2.o -o %t
// RUN: llvm-dwarfdump -eh-frame %t | FileCheck %s

// CHECK:   DW_CFA_def_cfa_offset: +64
// CHECK:   DW_CFA_def_cfa_offset: +32

.cfi_startproc
.cfi_def_cfa_offset 64
.cfi_endproc
