# REQUIRES: ppc

# RUN: llvm-mc -filetype=obj -triple=powerpc64le-unknown-linux %s -o %t
# RUN: ld.lld %t -o %t2
# RUN: llvm-objdump -d %t2 | FileCheck %s

# RUN: llvm-mc -filetype=obj -triple=powerpc64-unknown-linux %s -o %t
# RUN: ld.lld %t -o %t2
# RUN: llvm-objdump -d %t2 | FileCheck %s

# CHECK: Disassembly of section .text:

.text
.global _start
_start:
.Lfoo:
  li      0,1
  li      3,42
  sc

# CHECK: 10010000:       {{.*}}     li 0, 1
# CHECK: 10010004:       {{.*}}     li 3, 42
# CHECK: 10010008:       {{.*}}     sc

.global bar
bar:
  bl _start
  nop
  bl .Lfoo
  nop
  blr

# FIXME: The printing here is misleading, the branch offset here is negative.
# CHECK: 1001000c:       {{.*}}     bl .+67108852
# CHECK: 10010010:       {{.*}}     nop
# CHECK: 10010014:       {{.*}}     bl .+67108844
# CHECK: 10010018:       {{.*}}     nop
# CHECK: 1001001c:       {{.*}}     blr
