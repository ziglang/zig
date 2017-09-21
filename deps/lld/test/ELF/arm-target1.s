// REQUIRES: arm
// RUN: llvm-mc -filetype=obj -triple=armv7a-none-linux-gnueabi %s -o %t.o
// RUN: llvm-readobj -r %t.o | FileCheck %s --check-prefix=RELOC
// RUN: ld.lld -shared %t.o -o %t2.so --target1-rel
// RUN: llvm-objdump -t -d %t2.so | FileCheck %s \
// RUN:   --check-prefix=RELATIVE
// RUN: not ld.lld -shared %t.o -o %t3.so 2>&1 | FileCheck %s \
// RUN:   --check-prefix=ABS

// RUN: ld.lld -shared %t.o -o %t2.so --target1-abs --target1-rel
// RUN: llvm-objdump -t -d %t2.so | FileCheck %s \
// RUN:   --check-prefix=RELATIVE
// RUN: not ld.lld -shared %t.o -o %t3.so --target1-rel --target1-abs 2>&1 \
// RUN:   | FileCheck %s --check-prefix=ABS

// RELOC: Relocations [
// RELOC:   .rel.text {
// RELOC:     0x0 R_ARM_TARGET1 patatino 0x0
// RELOC:   }
// RELOC: ]

.text
  .word patatino(target1)
  patatino:
        .word 32
// Force generation of $d.0 as section is not all data
  nop
// RELATIVE: Disassembly of section .text:
// RELATIVE: $d.0:
// RELATIVE:     1000:       04 00 00 00     .word   0x00000004
// RELATIVE: SYMBOL TABLE:
// RELATIVE: 00001004         .text           00000000 patatino

// ABS: can't create dynamic relocation R_ARM_TARGET1 against symbol: patatino
// ABS: >>> defined in {{.*}}.o
// ABS: >>> referenced by {{.*}}.o:(.text+0x0)
