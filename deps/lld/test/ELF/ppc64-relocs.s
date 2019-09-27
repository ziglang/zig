# REQUIRES: ppc

# RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %s -o %t.o
# RUN: ld.lld --no-toc-optimize %t.o -o %t
# RUN: llvm-readelf -x .rodata -x .R_PPC64_TOC -x .eh_frame %t | FileCheck %s --check-prefix=DATALE
# RUN: llvm-objdump -d --no-show-raw-insn %t | FileCheck %s

# RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %s -o %t.o
# RUN: ld.lld --no-toc-optimize %t.o -o %t
# RUN: llvm-readelf -x .rodata -x .R_PPC64_TOC -x .eh_frame %t | FileCheck %s --check-prefix=DATABE
# RUN: llvm-objdump -d --no-show-raw-insn %t | FileCheck %s

.text
.global _start
_start:
.Lfoo:
	li      0,1
	li      3,42
	sc

.section .toc,"aw",@progbits
.L1:
  .quad 22, 37, 89, 47

.section .R_PPC64_TOC16_LO_DS,"ax",@progbits
  ld 1, .L1@toc@l(2)

# CHECK-LABEL: Disassembly of section .R_PPC64_TOC16_LO_DS:
# CHECK: 1001000c:       ld 1, -32768(2)

.section .R_PPC64_TOC16_LO,"ax",@progbits
  addi  1, 2, .L1@toc@l

# CHECK-LABEL: Disassembly of section .R_PPC64_TOC16_LO:
# CHECK: 10010010:       addi 1, 2, -32768

.section .R_PPC64_TOC16_HI,"ax",@progbits
  addis 1, 2, .L1@toc@h

# CHECK-LABEL: Disassembly of section .R_PPC64_TOC16_HI:
# CHECK: 10010014:       addis 1, 2, -1

.section .R_PPC64_TOC16_HA,"ax",@progbits
  addis 1, 2, .L1@toc@ha

# CHECK-LABEL: Disassembly of section .R_PPC64_TOC16_HA:
# CHECK: 10010018:       addis 1, 2, 0

.section .R_PPC64_ADDR16_LO,"ax",@progbits
  li 1, .Lfoo@l

# CHECK-LABEL: Disassembly of section .R_PPC64_ADDR16_LO:
# CHECK: li 1, 0

.section .R_PPC64_ADDR16_HI,"ax",@progbits
  li 1, .Lfoo@h

# CHECK-LABEL: Disassembly of section .R_PPC64_ADDR16_HI:
# CHECK: li 1, 4097

.section .R_PPC64_ADDR16_HA,"ax",@progbits
  li 1, .Lfoo@ha

# CHECK-LABEL: Disassembly of section .R_PPC64_ADDR16_HA:
# CHECK: li 1, 4097

.section .R_PPC64_ADDR16_HIGHER,"ax",@progbits
  li 1, .Lfoo@higher

# CHECK-LABEL: Disassembly of section .R_PPC64_ADDR16_HIGHER:
# CHECK: li 1, 0

.section .R_PPC64_ADDR16_HIGHERA,"ax",@progbits
  li 1, .Lfoo@highera

# CHECK-LABEL: Disassembly of section .R_PPC64_ADDR16_HIGHERA:
# CHECK: li 1, 0

.section .R_PPC64_ADDR16_HIGHEST,"ax",@progbits
  li 1, .Lfoo@highest

# CHECK-LABEL: Disassembly of section .R_PPC64_ADDR16_HIGHEST:
# CHECK: li 1, 0

.section .R_PPC64_ADDR16_HIGHESTA,"ax",@progbits
  li 1, .Lfoo@highesta

# CHECK-LABEL: Disassembly of section .R_PPC64_ADDR16_HIGHESTA:
# CHECK: li 1, 0

.section .R_PPC64_TOC,"a",@progbits
  .quad .TOC.@tocbase

# SEC: .got PROGBITS 0000000010020000

## tocbase = .got+0x8000 = 0x10028000
# DATALE-LABEL: section '.R_PPC64_TOC':
# DATALE: 00800210 00000000

# DATABE-LABEL: section '.R_PPC64_TOC':
# DATABE: 00000000 10028000
