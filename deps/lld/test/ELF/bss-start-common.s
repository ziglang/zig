# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: ld.lld %t -o %t2
# RUN: llvm-objdump -t -section-headers %t2 | FileCheck %s

# CHECK: Sections:
# CHECK: Idx Name          Size      Address          Type
# CHECK:   2 .bss          00000004 0000000000201000 BSS
# CHECK: SYMBOL TABLE:
# CHECK: 0000000000201000  .bss 00000000 __bss_start

.global __bss_start
.text
_start:
.comm sym1,4,4
