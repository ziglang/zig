// REQUIRES: aarch64
# REQUIRES: aarch64
# RUN: llvm-mc -filetype=obj -triple=aarch64-unknown-freebsd %p/Inputs/aarch64-tls-ie.s -o %tdso.o
# RUN: llvm-mc -filetype=obj -triple=aarch64-unknown-freebsd %s -o %tmain.o
# RUN: ld.lld -shared %tdso.o -o %tdso.so
# RUN: ld.lld --hash-style=sysv %tmain.o %tdso.so -o %tout
# RUN: llvm-objdump -d %tout | FileCheck %s
# RUN: llvm-readobj -s -r %tout | FileCheck -check-prefix=RELOC %s

#RELOC:      Section {
#RELOC:        Index:
#RELOC:        Name: .got
#RELOC-NEXT:   Type: SHT_PROGBITS
#RELOC-NEXT:   Flags [
#RELOC-NEXT:     SHF_ALLOC
#RELOC-NEXT:     SHF_WRITE
#RELOC-NEXT:   ]
#RELOC-NEXT:   Address: 0x2200B0
#RELOC-NEXT:   Offset: 0x200B0
#RELOC-NEXT:   Size: 16
#RELOC-NEXT:   Link: 0
#RELOC-NEXT:   Info: 0
#RELOC-NEXT:   AddressAlignment: 8
#RELOC-NEXT:   EntrySize: 0
#RELOC-NEXT: }
#RELOC:      Relocations [
#RELOC-NEXT:  Section ({{.*}}) .rela.dyn {
#RELOC-NEXT:    0x2200B8 R_AARCH64_TLS_TPREL64 bar 0x0
#RELOC-NEXT:    0x2200B0 R_AARCH64_TLS_TPREL64 foo 0x0
#RELOC-NEXT:  }
#RELOC-NEXT:]

# Page(0x2200B0) - Page(0x210000) = 0x10000 = 65536
# 0x2200B0 & 0xff8 = 0xB0 = 176
# Page(0x2200B8) - Page(0x210000) = 0x10000 = 65536
# 0x2200B8 & 0xff8 = 0xB8 = 184
#CHECK: Disassembly of section .text:
#CHECK: _start:
#CHECK:  210000: 80 00 00 90 adrp x0, #65536
#CHECK:  210004: 00 58 40 f9 ldr  x0, [x0, #176]
#CHECK:  210008: 80 00 00 90 adrp x0, #65536
#CHECK:  21000c: 00 5c 40 f9 ldr  x0, [x0, #184]

.globl _start
_start:
 adrp x0, :gottprel:foo
 ldr x0, [x0, #:gottprel_lo12:foo]

 adrp x0, :gottprel:bar
 ldr x0, [x0, #:gottprel_lo12:bar]
