// REQUIRES: x86
// RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
// RUN: ld.lld %t.o -o %t1
// RUN: llvm-readobj -r %t1 | FileCheck --check-prefix=NORELOC %s
// RUN: llvm-objdump -d %t1 | FileCheck --check-prefix=DISASM %s
// RUN: ld.lld -shared %t.o -o %t1
// RUN: llvm-readobj -r %t1 | FileCheck --check-prefix=RELOCSHARED %s
// RUN: llvm-objdump -d %t1 | FileCheck --check-prefix=DISASMSHARED %s

// NORELOC:      Relocations [
// NORELOC-NEXT: ]

// DISASM:      Disassembly of section test:
// DISASM-EMPTY:
// DISASM-NEXT: _data:
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
// DISASM-NEXT: 201018: 19 00
// DISASM-NEXT: 20101a: 00 00
// DISASM-NEXT: 20101c: 00 00
// DISASM-NEXT: 20101e: 00 00
// DISASM-NEXT: 201020: 1a 00
// DISASM-NEXT: 201022: 00 00
// DISASM-NEXT: 201024: 00 00
// DISASM-NEXT: 201026: 00 00
// DISASM-NEXT: 201028: 1b 00
// DISASM-NEXT: 20102a: 00 00
// DISASM-NEXT: 20102c: 00 00
// DISASM-NEXT: 20102e: 00 00
// DISASM:      _start:
// DISASM-NEXT: 201030: 8b 04 25 19 00 00 00 movl 25, %eax
// DISASM-NEXT: 201037: 8b 04 25 1a 00 00 00 movl 26, %eax
// DISASM-NEXT: 20103e: 8b 04 25 1b 00 00 00 movl 27, %eax
// DISASM-NEXT: 201045: 8b 04 25 19 00 00 00 movl 25, %eax
// DISASM-NEXT: 20104c: 8b 04 25 1a 00 00 00 movl 26, %eax
// DISASM-NEXT: 201053: 8b 04 25 1b 00 00 00 movl 27, %eax

// RELOCSHARED:      Relocations [
// RELOCSHARED-NEXT: Section ({{.*}}) .rela.dyn {
// RELOCSHARED-NEXT:    0x1000 R_X86_64_SIZE64 foo 0xFFFFFFFFFFFFFFFF
// RELOCSHARED-NEXT:    0x1008 R_X86_64_SIZE64 foo 0x0
// RELOCSHARED-NEXT:    0x1010 R_X86_64_SIZE64 foo 0x1
// RELOCSHARED-NEXT:    0x1033 R_X86_64_SIZE32 foo 0xFFFFFFFFFFFFFFFF
// RELOCSHARED-NEXT:    0x103A R_X86_64_SIZE32 foo 0x0
// RELOCSHARED-NEXT:    0x1041 R_X86_64_SIZE32 foo 0x1
// RELOCSHARED-NEXT:  }
// RELOCSHARED-NEXT: ]

// DISASMSHARED:      Disassembly of section test:
// DISASMSHARED-EMPTY:
// DISASMSHARED-NEXT: _data:
// DISASMSHARED-NEXT: ...
// DISASMSHARED-NEXT: 1018: 19 00
// DISASMSHARED-NEXT: 101a: 00 00
// DISASMSHARED-NEXT: 101c: 00 00
// DISASMSHARED-NEXT: 101e: 00 00
// DISASMSHARED-NEXT: 1020: 1a 00
// DISASMSHARED-NEXT: 1022: 00 00
// DISASMSHARED-NEXT: 1024: 00 00
// DISASMSHARED-NEXT: 1026: 00 00
// DISASMSHARED-NEXT: 1028: 1b 00
// DISASMSHARED-NEXT: 102a: 00 00
// DISASMSHARED-NEXT: 102c: 00 00
// DISASMSHARED-NEXT: 102e: 00 00
// DISASMSHARED:      _start:
// DISASMSHARED-NEXT: 1030: 8b 04 25 00 00 00 00 movl 0, %eax
// DISASMSHARED-NEXT: 1037: 8b 04 25 00 00 00 00 movl 0, %eax
// DISASMSHARED-NEXT: 103e: 8b 04 25 00 00 00 00 movl 0, %eax
// DISASMSHARED-NEXT: 1045: 8b 04 25 19 00 00 00 movl 25, %eax
// DISASMSHARED-NEXT: 104c: 8b 04 25 1a 00 00 00 movl 26, %eax
// DISASMSHARED-NEXT: 1053: 8b 04 25 1b 00 00 00 movl 27, %eax

.data
.global foo
.type foo,%object
.size foo,26
foo:
.zero 26

.data
.global foohidden
.hidden foohidden
.type foohidden,%object
.size foohidden,26
foohidden:
.zero 26

.section test,"axw"
_data:
  // R_X86_64_SIZE64:
  .quad foo@SIZE-1
  .quad foo@SIZE
  .quad foo@SIZE+1
  .quad foohidden@SIZE-1
  .quad foohidden@SIZE
  .quad foohidden@SIZE+1
.globl _start
_start:
  // R_X86_64_SIZE32:
  movl foo@SIZE-1,%eax
  movl foo@SIZE,%eax
  movl foo@SIZE+1,%eax
  movl foohidden@SIZE-1,%eax
  movl foohidden@SIZE,%eax
  movl foohidden@SIZE+1,%eax
