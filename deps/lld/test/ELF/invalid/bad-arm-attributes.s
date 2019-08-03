# REQUIRES: arm
# RUN: llvm-mc -filetype=obj -triple=arm-unknown-linux %s -o %t
# RUN: ld.lld %t -o /dev/null 2>&1 | FileCheck %s

# CHECK: invalid subsection length 0 at offset 1

.section .ARM.attributes,"a",%0x70000003
  .quad 0
