# REQUIRES: ppc

# RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %s -o %t
# RUN: ld.lld %t -o %t2
# RUN: llvm-objdump -d --no-show-raw-insn %t2 | FileCheck %s

# RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %s -o %t
# RUN: ld.lld %t -o %t2
# RUN: llvm-objdump -d --no-show-raw-insn %t2 | FileCheck %s

# CHECK: Disassembly of section .text:
# CHECK-EMPTY:

.text
.global _start
_start:
  bl weakfunc
  nop
  blr

.weak weakfunc

# It does not really matter how we fixup the bl, if at all, because it needs to
# be unreachable. But, we should link successfully. We should not, however,
# generate a .plt entry (this would be wasted space). For now, we do nothing
# (leaving the zero relative offset present in the input).
# CHECK: 10010000:       bl .+0
# CHECK: 10010004:       nop
# CHECK: 10010008:       blr
