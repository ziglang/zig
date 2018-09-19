# REQUIRES: x86
# This test is to make sure that we can handle implicit addends properly.

# RUN: llvm-mc -filetype=obj -triple=i386-unknown-linux %s -o %t
# RUN: ld.lld %t -o /dev/null --icf=all --print-icf-sections 2>&1 | FileCheck %s

# CHECK:     selected section {{.*}}:(.text.f1)
# CHECK:       removing identical section {{.*}}:(.text.f2)
# CHECK-NOT:   removing identical section {{.*}}:(.text.f3)

.globl _start, f1, f2, f3
_start:
  ret

.section .text.f1, "ax"
f1:
  movl $42, 4(%edi)

.section .text.f2, "ax"
f2:
  movl $42, 4(%edi)

.section .text.f3, "ax"
f3:
  movl $42, 8(%edi)
