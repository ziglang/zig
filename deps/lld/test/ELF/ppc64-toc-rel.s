# REQUIRES: ppc

# RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %s -o %t.o
# RUN: llvm-readobj -r %t.o | FileCheck -check-prefix=RELOCS-LE %s
# RUN: ld.lld %t.o -o %t
# RUN: llvm-nm %t | FileCheck --check-prefix=NM %s
# RUN: llvm-readelf -x .got %t | FileCheck --check-prefix=HEX-LE %s
# RUN: llvm-objdump -d --no-show-raw-insn %t | FileCheck --check-prefix=CHECK %s

# RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %s -o %t.o
# RUN: llvm-readobj -r %t.o | FileCheck -check-prefix=RELOCS-BE %s
# RUN: ld.lld %t.o -o %t
# RUN: llvm-nm %t | FileCheck --check-prefix=NM %s
# RUN: llvm-readelf -x .got %t | FileCheck --check-prefix=HEX-BE %s
# RUN: llvm-objdump -d --no-show-raw-insn %t | FileCheck --check-prefix=CHECK %s

# Make sure we calculate the offset correctly for a toc-relative access to a
# global variable as described by the PPC64 Elf V2 abi.
.abiversion 2

#  int global_a = 55
   .globl      global_a
   .section    ".data"
   .align      2
   .type       global_a, @object
   .size       global_a, 4
   .p2align    2
global_a:
   .long   41


   .section        ".text"
   .align 2
   .global _start
   .type   _start, @function
_start:
.Lfunc_gep0:
    addis 2, 12, .TOC.-.Lfunc_gep0@ha
    addi 2, 2, .TOC.-.Lfunc_gep0@l
.Lfunc_lep0:
    .localentry _start, .Lfunc_lep0-.Lfunc_gep0

    addis 3, 2, global_a@toc@ha
    addi 3, 3, global_a@toc@l
    li 0,1
    lwa 3, 0(3)
    sc
.size   _start,.-_start

# Verify the relocations that get emitted for the global variable are the
# expected ones.
# RELOCS-LE:      Relocations [
# RELOCS-LE-NEXT:   .rela.text {
# RELOCS-LE:          0x8 R_PPC64_TOC16_HA global_a 0x0
# RELOCS-LE:          0xC R_PPC64_TOC16_LO global_a 0x0

# RELOCS-BE:      Relocations [
# RELOCS-BE-NEXT:   .rela.text {
# RELOCS-BE:          0xA R_PPC64_TOC16_HA global_a 0x0
# RELOCS-BE:          0xE R_PPC64_TOC16_LO global_a 0x0

# The .TOC. symbol represents the TOC base address: .got + 0x8000 = 0x10028000,
# which is stored in the first entry of .got
# NM: 0000000010028000 d .TOC.
# NM: 0000000010030000 D global_a
# HEX-LE:     section '.got':
# HEX-LE-NEXT: 0x10020000 00800210 00000000
# HEX-BE:     section '.got':
# HEX-BE-NEXT: 0x10020000 00000000 10028000

# r2 stores the TOC base address. To access global_a with r3, it
# computes the address with TOC plus an offset.
# The offset global_a - .TOC. = 0x10030000 - 0x10028000 = 0x8000
# gets materialized as (1 << 16) - 32768.
# CHECK:      _start:
# CHECK:      10010008:       addis 3, 2, 1
# CHECK-NEXT: 1001000c:       addi 3, 3, -32768
