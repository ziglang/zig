// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %p/Inputs/relocation-size-shared.s -o %tso.o
// RUN: ld.lld -shared %tso.o -o %tso
// RUN: ld.lld %t.o %tso -o %t1
// RUN: llvm-readobj -r %t1 | FileCheck --check-prefix=RELOCSHARED %s
// RUN: llvm-objdump -d %t1 | FileCheck --check-prefix=DISASM %s

// RELOCSHARED:       Relocations [
// RELOCSHARED-NEXT:  Section ({{.*}}) .rela.dyn {
// RELOCSHARED-NEXT:    0x201018 R_X86_64_SIZE64 fooshared 0xFFFFFFFFFFFFFFFF
// RELOCSHARED-NEXT:    0x201020 R_X86_64_SIZE64 fooshared 0x0
// RELOCSHARED-NEXT:    0x201028 R_X86_64_SIZE64 fooshared 0x1
// RELOCSHARED-NEXT:    0x201048 R_X86_64_SIZE32 fooshared 0xFFFFFFFFFFFFFFFF
// RELOCSHARED-NEXT:    0x20104F R_X86_64_SIZE32 fooshared 0x0
// RELOCSHARED-NEXT:    0x201056 R_X86_64_SIZE32 fooshared 0x1
// RELOCSHARED-NEXT:  }
// RELOCSHARED-NEXT:]

// DISASM:      Disassembly of section test
// DISASM:      _data:
// DISASM-NEXT: 201000: 19 00
// DISASM-NEXT: 201002: 00 00
// DISASM-NEXT: 201004: 00 00
// DISASM-NEXT: 201006: 00 00
// DISASM-NEXT: 201008: 1a 00
// DISASM-NEXT: 20100a: 00 00
// DISASM-NEXT: 20100c: 00 00
// DISASM-NEXT: 20100e: 00 00
// DISASM-NEXT: 201010: 1b 00
// DISASM-NEXT: 201012: 00 00
// DISASM-NEXT: 201014: 00 00
// DISASM-NEXT: 201016: 00 00
// DISASM-NEXT: 201018: 00 00
// DISASM-NEXT: 20101a: 00 00
// DISASM-NEXT: 20101c: 00 00
// DISASM-NEXT: 20101e: 00 00
// DISASM-NEXT: 201020: 00 00
// DISASM-NEXT: 201022: 00 00
// DISASM-NEXT: 201024: 00 00
// DISASM-NEXT: 201026: 00 00
// DISASM-NEXT: 201028: 00 00
// DISASM-NEXT: 20102a: 00 00
// DISASM-NEXT: 20102c: 00 00
// DISASM-NEXT: 20102e: 00 00
// DISASM:      _start:
// DISASM-NEXT: 201030: 8b 04 25 19 00 00 00 movl 25, %eax
// DISASM-NEXT: 201037: 8b 04 25 1a 00 00 00 movl 26, %eax
// DISASM-NEXT: 20103e: 8b 04 25 1b 00 00 00 movl 27, %eax
// DISASM-NEXT: 201045: 8b 04 25 00 00 00 00 movl 0, %eax
// DISASM-NEXT: 20104c: 8b 04 25 00 00 00 00 movl 0, %eax
// DISASM-NEXT: 201053: 8b 04 25 00 00 00 00 movl 0, %eax

.data
.global foo
.type foo,%object
.size foo,26
foo:
.zero 26

.section test, "awx"
_data:
  // R_X86_64_SIZE64:
  .quad foo@SIZE-1
  .quad foo@SIZE
  .quad foo@SIZE+1
  .quad fooshared@SIZE-1
  .quad fooshared@SIZE
  .quad fooshared@SIZE+1

.globl _start
_start:
  // R_X86_64_SIZE32:
  movl foo@SIZE-1,%eax
  movl foo@SIZE,%eax
  movl foo@SIZE+1,%eax
  movl fooshared@SIZE-1,%eax
  movl fooshared@SIZE,%eax
  movl fooshared@SIZE+1,%eax
