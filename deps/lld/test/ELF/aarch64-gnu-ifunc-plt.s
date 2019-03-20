// REQUIRES: aarch64
// RUN: llvm-mc -filetype=obj -triple=aarch64-none-linux-gnu %S/Inputs/shared2.s -o %t1.o
// RUN: ld.lld %t1.o --shared -o %t.so
// RUN: llvm-mc -filetype=obj -triple=aarch64-none-linux-gnu %s -o %t.o
// RUN: ld.lld --hash-style=sysv %t.so %t.o -o %tout
// RUN: llvm-objdump -d %tout | FileCheck %s --check-prefix=DISASM
// RUN: llvm-objdump -s %tout | FileCheck %s --check-prefix=GOTPLT
// RUN: llvm-readobj -r -dynamic-table %tout | FileCheck %s

// Check that the IRELATIVE relocations are after the JUMP_SLOT in the plt
// CHECK: Relocations [
// CHECK-NEXT:   Section (4) .rela.plt {
// CHECK:     0x220018 R_AARCH64_JUMP_SLOT bar2 0x0
// CHECK-NEXT:     0x220020 R_AARCH64_JUMP_SLOT zed2 0x0
// CHECK-NEXT:     0x220028 R_AARCH64_IRELATIVE - 0x210000
// CHECK-NEXT:     0x220030 R_AARCH64_IRELATIVE - 0x210004
// CHECK-NEXT:   }
// CHECK-NEXT: ]

// Check that .got.plt entries point back to PLT header
// GOTPLT: Contents of section .got.plt:
// GOTPLT-NEXT:  220000 00000000 00000000 00000000 00000000
// GOTPLT-NEXT:  220010 00000000 00000000 20002100 00000000
// GOTPLT-NEXT:  220020 20002100 00000000 20002100 00000000
// GOTPLT-NEXT:  220030 20002100 00000000

// Check that the PLTRELSZ tag includes the IRELATIVE relocations
// CHECK: DynamicSection [
// CHECK:   0x0000000000000002 PLTRELSZ             96 (bytes)

// Check that a PLT header is written and the ifunc entries appear last
// DISASM: Disassembly of section .text:
// DISASM-NEXT: foo:
// DISASM-NEXT:    210000: {{.*}} ret
// DISASM:      bar:
// DISASM-NEXT:    210004: {{.*}} ret
// DISASM:      _start:
// DISASM-NEXT:    210008: {{.*}} bl      #88
// DISASM-NEXT:    21000c: {{.*}} bl      #100
// DISASM-NEXT:    210010: {{.*}} bl      #48
// DISASM-NEXT:    210014: {{.*}} bl      #60
// DISASM-NEXT: Disassembly of section .plt:
// DISASM-NEXT: .plt:
// DISASM-NEXT:    210020: {{.*}} stp     x16, x30, [sp, #-16]!
// DISASM-NEXT:    210024: {{.*}} adrp    x16, #65536
// DISASM-NEXT:    210028: {{.*}} ldr     x17, [x16, #16]
// DISASM-NEXT:    21002c: {{.*}} add     x16, x16, #16
// DISASM-NEXT:    210030: {{.*}} br      x17
// DISASM-NEXT:    210034: {{.*}} nop
// DISASM-NEXT:    210038: {{.*}} nop
// DISASM-NEXT:    21003c: {{.*}} nop
// DISASM-EMPTY:
// DISASM-NEXT:   bar2@plt:
// DISASM-NEXT:    210040: {{.*}} adrp    x16, #65536
// DISASM-NEXT:    210044: {{.*}} ldr     x17, [x16, #24]
// DISASM-NEXT:    210048: {{.*}} add     x16, x16, #24
// DISASM-NEXT:    21004c: {{.*}} br      x17
// DISASM-EMPTY:
// DISASM-NEXT:   zed2@plt:
// DISASM-NEXT:    210050: {{.*}} adrp    x16, #65536
// DISASM-NEXT:    210054: {{.*}} ldr     x17, [x16, #32]
// DISASM-NEXT:    210058: {{.*}} add     x16, x16, #32
// DISASM-NEXT:    21005c: {{.*}} br      x17
// DISASM-NEXT:    210060: {{.*}} adrp    x16, #65536
// DISASM-NEXT:    210064: {{.*}} ldr     x17, [x16, #40]
// DISASM-NEXT:    210068: {{.*}} add     x16, x16, #40
// DISASM-NEXT:    21006c: {{.*}} br      x17
// DISASM-NEXT:    210070: {{.*}} adrp    x16, #65536
// DISASM-NEXT:    210074: {{.*}} ldr     x17, [x16, #48]
// DISASM-NEXT:    210078: {{.*}} add     x16, x16, #48
// DISASM-NEXT:    21007c: {{.*}} br      x17

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
