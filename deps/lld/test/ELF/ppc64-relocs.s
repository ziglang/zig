# RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %s -o %t
# RUN: ld.lld %t -o %t2
# RUN: llvm-objdump -d %t2 | FileCheck %s
# REQUIRES: ppc

.section        ".opd","aw"
.global _start
_start:
.quad   .Lfoo,.TOC.@tocbase,0

.text
.Lfoo:
	li      0,1
	li      3,42
	sc

.section        ".toc","aw"
.L1:
.quad           22, 37, 89, 47

.section .R_PPC64_TOC16_LO_DS,"ax",@progbits
.globl .FR_PPC64_TOC16_LO_DS
.FR_PPC64_TOC16_LO_DS:
  ld 1, .L1@toc@l(2)

# CHECK: Disassembly of section .R_PPC64_TOC16_LO_DS:
# CHECK: .FR_PPC64_TOC16_LO_DS:
# CHECK: 1001000c:       e8 22 80 00     ld 1, -32768(2)

.section .R_PPC64_TOC16_LO,"ax",@progbits
.globl .FR_PPC64_TOC16_LO
.FR_PPC64_TOC16_LO:
  addi  1, 2, .L1@toc@l

# CHECK: Disassembly of section .R_PPC64_TOC16_LO:
# CHECK: .FR_PPC64_TOC16_LO:
# CHECK: 10010010: 38 22 80 00 addi 1, 2, -32768

.section .R_PPC64_TOC16_HI,"ax",@progbits
.globl .FR_PPC64_TOC16_HI
.FR_PPC64_TOC16_HI:
  addis 1, 2, .L1@toc@h

# CHECK: Disassembly of section .R_PPC64_TOC16_HI:
# CHECK: .FR_PPC64_TOC16_HI:
# CHECK: 10010014: 3c 22 ff fe addis 1, 2, -2

.section .R_PPC64_TOC16_HA,"ax",@progbits
.globl .FR_PPC64_TOC16_HA
.FR_PPC64_TOC16_HA:
  addis 1, 2, .L1@toc@ha

# CHECK: Disassembly of section .R_PPC64_TOC16_HA:
# CHECK: .FR_PPC64_TOC16_HA:
# CHECK: 10010018: 3c 22 ff ff addis 1, 2, -1

.section .R_PPC64_REL24,"ax",@progbits
.globl .FR_PPC64_REL24
.FR_PPC64_REL24:
  b .Lfoox
.section .R_PPC64_REL24_2,"ax",@progbits
.Lfoox:

# CHECK: Disassembly of section .R_PPC64_REL24:
# CHECK: .FR_PPC64_REL24:
# CHECK: 1001001c: 48 00 00 04 b .+4

.section .R_PPC64_ADDR16_LO,"ax",@progbits
.globl .FR_PPC64_ADDR16_LO
.FR_PPC64_ADDR16_LO:
  li 1, .Lfoo@l

# CHECK: Disassembly of section .R_PPC64_ADDR16_LO:
# CHECK: .FR_PPC64_ADDR16_LO:
# CHECK: 10010020: 38 20 00 00 li 1, 0

.section .R_PPC64_ADDR16_HI,"ax",@progbits
.globl .FR_PPC64_ADDR16_HI
.FR_PPC64_ADDR16_HI:
  li 1, .Lfoo@h

# CHECK: Disassembly of section .R_PPC64_ADDR16_HI:
# CHECK: .FR_PPC64_ADDR16_HI:
# CHECK: 10010024: 38 20 10 01 li 1, 4097

.section .R_PPC64_ADDR16_HA,"ax",@progbits
.globl .FR_PPC64_ADDR16_HA
.FR_PPC64_ADDR16_HA:
  li 1, .Lfoo@ha

# CHECK: Disassembly of section .R_PPC64_ADDR16_HA:
# CHECK: .FR_PPC64_ADDR16_HA:
# CHECK: 10010028: 38 20 10 01 li 1, 4097

.section .R_PPC64_ADDR16_HIGHER,"ax",@progbits
.globl .FR_PPC64_ADDR16_HIGHER
.FR_PPC64_ADDR16_HIGHER:
  li 1, .Lfoo@higher

# CHECK: Disassembly of section .R_PPC64_ADDR16_HIGHER:
# CHECK: .FR_PPC64_ADDR16_HIGHER:
# CHECK: 1001002c: 38 20 00 00 li 1, 0

.section .R_PPC64_ADDR16_HIGHERA,"ax",@progbits
.globl .FR_PPC64_ADDR16_HIGHERA
.FR_PPC64_ADDR16_HIGHERA:
  li 1, .Lfoo@highera

# CHECK: Disassembly of section .R_PPC64_ADDR16_HIGHERA:
# CHECK: .FR_PPC64_ADDR16_HIGHERA:
# CHECK: 10010030: 38 20 00 00 li 1, 0

.section .R_PPC64_ADDR16_HIGHEST,"ax",@progbits
.globl .FR_PPC64_ADDR16_HIGHEST
.FR_PPC64_ADDR16_HIGHEST:
  li 1, .Lfoo@highest

# CHECK: Disassembly of section .R_PPC64_ADDR16_HIGHEST:
# CHECK: .FR_PPC64_ADDR16_HIGHEST:
# CHECK: 10010034: 38 20 00 00 li 1, 0

.section .R_PPC64_ADDR16_HIGHESTA,"ax",@progbits
.globl .FR_PPC64_ADDR16_HIGHESTA
.FR_PPC64_ADDR16_HIGHESTA:
  li 1, .Lfoo@highesta

# CHECK: Disassembly of section .R_PPC64_ADDR16_HIGHESTA:
# CHECK: .FR_PPC64_ADDR16_HIGHESTA:
# CHECK: 10010038: 38 20 00 00 li 1, 0

