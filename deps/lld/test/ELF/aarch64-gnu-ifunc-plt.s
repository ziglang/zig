// RUN: llvm-mc -filetype=obj -triple=aarch64-none-linux-gnu %S/Inputs/shared2.s -o %t1.o
// RUN: ld.lld %t1.o --shared -o %t.so
// RUN: llvm-mc -filetype=obj -triple=aarch64-none-linux-gnu %s -o %t.o
// RUN: ld.lld %t.so %t.o -o %tout
// RUN: llvm-objdump -d %tout | FileCheck %s --check-prefix=DISASM
// RUN: llvm-objdump -s %tout | FileCheck %s --check-prefix=GOTPLT
// RUN: llvm-readobj -r -dynamic-table %tout | FileCheck %s
// REQUIRES: aarch64

// Check that the IRELATIVE relocations are after the JUMP_SLOT in the plt
// CHECK: Relocations [
// CHECK-NEXT:   Section (4) .rela.plt {
// CHECK:     0x30018 R_AARCH64_JUMP_SLOT bar2 0x0
// CHECK-NEXT:     0x30020 R_AARCH64_JUMP_SLOT zed2 0x0
// CHECK-NEXT:     0x30028 R_AARCH64_IRELATIVE - 0x20000
// CHECK-NEXT:     0x30030 R_AARCH64_IRELATIVE - 0x20004
// CHECK-NEXT:   }
// CHECK-NEXT: ]

// Check that .got.plt entries point back to PLT header
// GOTPLT: Contents of section .got.plt:
// GOTPLT-NEXT:  30000 00000000 00000000 00000000 00000000
// GOTPLT-NEXT:  30010 00000000 00000000 20000200 00000000
// GOTPLT-NEXT:  30020 20000200 00000000 20000200 00000000
// GOTPLT-NEXT:  30030 20000200 00000000

// Check that the PLTRELSZ tag includes the IRELATIVE relocations
// CHECK: DynamicSection [
// CHECK:   0x0000000000000002 PLTRELSZ             96 (bytes)

// Check that a PLT header is written and the ifunc entries appear last
// DISASM: Disassembly of section .text:
// DISASM-NEXT: foo:
// DISASM-NEXT:    20000: {{.*}} ret
// DISASM:      bar:
// DISASM-NEXT:    20004: {{.*}} ret
// DISASM:      _start:
// DISASM-NEXT:    20008: {{.*}} bl      #88
// DISASM-NEXT:    2000c: {{.*}} bl      #100
// DISASM-NEXT:    20010: {{.*}} bl      #48
// DISASM-NEXT:    20014: {{.*}} bl      #60
// DISASM-NEXT: Disassembly of section .plt:
// DISASM-NEXT: .plt:
// DISASM-NEXT:    20020: {{.*}} stp     x16, x30, [sp, #-16]!
// DISASM-NEXT:    20024: {{.*}} adrp    x16, #65536
// DISASM-NEXT:    20028: {{.*}} ldr     x17, [x16, #16]
// DISASM-NEXT:    2002c: {{.*}} add     x16, x16, #16
// DISASM-NEXT:    20030: {{.*}} br      x17
// DISASM-NEXT:    20034: {{.*}} nop
// DISASM-NEXT:    20038: {{.*}} nop
// DISASM-NEXT:    2003c: {{.*}} nop
// DISASM-NEXT:    20040: {{.*}} adrp    x16, #65536
// DISASM-NEXT:    20044: {{.*}} ldr     x17, [x16, #24]
// DISASM-NEXT:    20048: {{.*}} add     x16, x16, #24
// DISASM-NEXT:    2004c: {{.*}} br      x17
// DISASM-NEXT:    20050: {{.*}} adrp    x16, #65536
// DISASM-NEXT:    20054: {{.*}} ldr     x17, [x16, #32]
// DISASM-NEXT:    20058: {{.*}} add     x16, x16, #32
// DISASM-NEXT:    2005c: {{.*}} br      x17
// DISASM-NEXT:    20060: {{.*}} adrp    x16, #65536
// DISASM-NEXT:    20064: {{.*}} ldr     x17, [x16, #40]
// DISASM-NEXT:    20068: {{.*}} add     x16, x16, #40
// DISASM-NEXT:    2006c: {{.*}} br      x17
// DISASM-NEXT:    20070: {{.*}} adrp    x16, #65536
// DISASM-NEXT:    20074: {{.*}} ldr     x17, [x16, #48]
// DISASM-NEXT:    20078: {{.*}} add     x16, x16, #48
// DISASM-NEXT:    2007c: {{.*}} br      x17

.text
.type foo STT_GNU_IFUNC
.globl foo
foo:
 ret

.type bar STT_GNU_IFUNC
.globl bar
bar:
 ret

.globl _start
_start:
 bl foo
 bl bar
 bl bar2
 bl zed2
