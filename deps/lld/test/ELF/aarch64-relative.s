// REQUIRES: aarch64
// RUN: llvm-mc -filetype=obj -triple=aarch64-unknown-freebsd %s -o %t.o
// RUN: ld.lld %t.o -o %t.so -shared
// RUN: llvm-readobj -r %t.so | FileCheck %s

  adr     x8, .Lfoo                 // R_AARCH64_ADR_PREL_LO21
  adrp    x8, .Lfoo                 // R_AARCH64_ADR_PREL_PG_HI21
  strb    w9, [x8, :lo12:.Lfoo]     // R_AARCH64_LDST8_ABS_LO12_NC
  ldr     h17, [x19, :lo12:.Lfoo]   // R_AARCH64_LDST16_ABS_LO12_NC
  ldr     w0, [x8, :lo12:.Lfoo]     // R_AARCH64_LDST32_ABS_LO12_NC
  ldr     x0, [x8, :lo12:.Lfoo]     // R_AARCH64_LDST64_ABS_LO12_NC
  ldr     q20, [x19, #:lo12:.Lfoo]  // R_AARCH64_LDST128_ABS_LO12_NC
  add     x0, x0, :lo12:.Lfoo       // R_AARCH64_ADD_ABS_LO12_NC
  bl      .Lfoo                     // R_AARCH64_CALL26
  b       .Lfoo                     // R_AARCH64_JUMP26
  beq     .Lfoo                     // R_AARCH64_CONDBR19
.Lbranch:
  tbz     x1, 7, .Lbranch           // R_AARCH64_TSTBR14
.data
.Lfoo:

.rodata
.long .Lfoo - .
.xword .Lfoo - .                    // R_AARCH64_PREL64
// CHECK:      Relocations [
// CHECK-NEXT: ]
