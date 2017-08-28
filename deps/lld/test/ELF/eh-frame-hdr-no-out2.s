// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
// RUN: ld.lld --eh-frame-hdr %t.o -o %t
// RUN: llvm-readobj -s -program-headers %t | FileCheck %s --check-prefix=NOHDR

.section foo,"ax",@progbits
 nop

.text
.globl _start
_start:

// There is no .eh_frame section,
// therefore .eh_frame_hdr also not created.
// NOHDR:       Sections [
// NOHDR-NOT:    Name: .eh_frame
// NOHDR-NOT:    Name: .eh_frame_hdr
// NOHDR:      ProgramHeaders [
// NOHDR-NOT:   PT_GNU_EH_FRAME
