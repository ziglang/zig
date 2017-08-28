# RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %s -o %t
# RUN: ld.lld %t -o %t2
# RUN: llvm-objdump -d %t2 | FileCheck %s
# REQUIRES: ppc

# CHECK: Disassembly of section .text:

.section        ".opd","aw"
.global _start
_start:
.quad   .Lfoo,.TOC.@tocbase,0

.text
.Lfoo:
  bl weakfunc
  nop
  blr

.weak weakfunc

# It does not really matter how we fixup the bl, if at all, because it needs to
# be unreachable. But, we should link successfully. We should not, however,
# generate a .plt entry (this would be wasted space). For now, we do nothing
# (leaving the zero relative offset present in the input).
# CHECK: 10010000:       48 00 00 01     bl .+0
# CHECK: 10010004:       60 00 00 00     nop
# CHECK: 10010008:       4e 80 00 20     blr
