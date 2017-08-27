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
  li      0,1
  li      3,42
  sc

# CHECK: 10010000:       38 00 00 01     li 0, 1
# CHECK: 10010004:       38 60 00 2a     li 3, 42
# CHECK: 10010008:       44 00 00 02     sc

.section        ".opd","aw"
.global bar
bar:
.quad   .Lbar,.TOC.@tocbase,0

.text
.Lbar:
  bl _start
  nop
  bl .Lfoo
  nop
  blr

# FIXME: The printing here is misleading, the branch offset here is negative.
# CHECK: 1001000c:       4b ff ff f5     bl .+67108852
# CHECK: 10010010:       60 00 00 00     nop
# CHECK: 10010014:       4b ff ff ed     bl .+67108844
# CHECK: 10010018:       60 00 00 00     nop
# CHECK: 1001001c:       4e 80 00 20     blr

