# REQUIRES: ppc

# RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %s -o %t.o
# RUN: llvm-readobj -relocations %t.o | FileCheck -check-prefix=RELOCS-LE %s
# RUN: ld.lld %t.o -o %t2
# RUN: llvm-objdump -D %t2 | FileCheck %s --check-prefix=CHECK-LE
# RUN: llvm-objdump -D %t2 | FileCheck %s

# RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %s -o %t.o
# RUN: llvm-readobj -relocations %t.o | FileCheck -check-prefix=RELOCS-BE %s
# RUN: ld.lld %t.o -o %t2
# RUN: llvm-objdump -D %t2 | FileCheck %s --check-prefix=CHECK-BE
# RUN: llvm-objdump -D %t2 | FileCheck %s

# Make sure we calculate the offset correctly for a got-indirect access to a
# global variable as described by the PPC64 ELF V2 abi.
  .text
  .abiversion 2
  .globl  _start                    # -- Begin function _start
  .p2align  4
  .type  _start,@function
_start:                                   # @_start
.Lfunc_begin0:
.Lfunc_gep0:
  addis 2, 12, .TOC.-.Lfunc_gep0@ha
  addi 2, 2, .TOC.-.Lfunc_gep0@l
.Lfunc_lep0:
  .localentry  _start, .Lfunc_lep0-.Lfunc_gep0
# %bb.0:                                # %entry
  addis 3, 2, .LC0@toc@ha
  ld 3, .LC0@toc@l(3)
  li 4, 0
  stw 4, -12(1)
  li 0,1
        lwa 3, 0(3)
  sc
  .long  0
  .quad  0
.Lfunc_end0:
  .size  _start, .Lfunc_end0-.Lfunc_begin0
                                        # -- End function
  .section  .toc,"aw",@progbits
.LC0:
  .tc glob[TC],glob
  .type  glob,@object            # @glob
  .data
  .globl  glob
  .p2align  2
glob:
  .long  55                      # 0x37
  .size  glob, 4

# Verify the relocations emitted for glob are through the .toc

# RELOCS-LE: Relocations [
# RELOCS-LE:  .rela.text {
# RELOCS-LE:     0x0 R_PPC64_REL16_HA .TOC. 0x0
# RELOCS-LE:     0x4 R_PPC64_REL16_LO .TOC. 0x4
# RELOCS-LE:     0x8 R_PPC64_TOC16_HA .toc 0x0
# RELOCS-LE:     0xC R_PPC64_TOC16_LO_DS .toc 0x0
# RELOCS-LE:   }
# RELOCS-LE:   .rela.toc {
# RELOCS-LE:     0x0 R_PPC64_ADDR64 glob 0x0
# RELOCS-LE:   }

# RELOCS-BE: Relocations [
# RELOCS-BE:  .rela.text {
# RELOCS-BE:    0x2 R_PPC64_REL16_HA .TOC. 0x2
# RELOCS-BE:    0x6 R_PPC64_REL16_LO .TOC. 0x6
# RELOCS-BE:    0xA R_PPC64_TOC16_HA .toc 0x0
# RELOCS-BE:    0xE R_PPC64_TOC16_LO_DS .toc 0x0
# RELOCS-BE:  }
# RELOCS-BE:  .rela.toc {
# RELOCS-BE:    0x0 R_PPC64_ADDR64 glob 0x0
# RELOCS-BE:  }
# RELOCS-BE:]

# Verify that the global variable access is done through the correct
# toc entry:
# r2 = .TOC. = 0x10038000.
# r3 = r2 - 32760 = 0x10030008 -> .toc entry for glob.

# CHECK: _start:
# CHECK-NEXT: 10010000:  {{.*}}   addis 2, 12, 3
# CHECK-NEXT: 10010004:  {{.*}}   addi 2, 2, -32768
# CHECK-NEXT: 10010008:  {{.*}}   nop
# CHECK-NEXT: 1001000c:  {{.*}}   ld 3, -32760(2)
# CHECK: 1001001c:  {{.*}}   lwa 3, 0(3)

# CHECK-LE: Disassembly of section .data:
# CHECK-LE-NEXT: glob:
# CHECK-LE-NEXT: 10020000:       37 00 00 00

# CHECK-LE: Disassembly of section .got:
# CHECK-LE-NEXT: .got:
# CHECK-LE-NEXT: 10030000:       00 80 03 10
# CHECK-LE-NEXT: 10030004:       00 00 00 00

# Verify that .toc comes right after .got
# CHECK-LE: Disassembly of section .toc:
# CHECK-LE: 10030008:       00 00 02 10

# CHECK-BE: Disassembly of section .data:
# CHECK-BE-NEXT: glob:
# CHECK-BE-NEXT: 10020000:       00 00 00 37

# CHECK-BE: Disassembly of section .got:
# CHECK-BE-NEXT: .got:
# CHECK-BE-NEXT: 10030000:       00 00 00 00
# CHECK-BE-NEXT: 10030004:       10 03 80 00

# Verify that .toc comes right after .got
# CHECK-BE: Disassembly of section .toc:
# CHECK-BE: 10030008:       00 00 00 00
# CHECK-BE: 1003000c:       10 02 00 00
