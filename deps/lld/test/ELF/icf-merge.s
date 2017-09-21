# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %S/Inputs/icf-merge.s -o %t1
# RUN: ld.lld %t %t1 -o %t1.out --icf=all --verbose | FileCheck %s

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %S/Inputs/icf-merge2.s -o %t2
# RUN: ld.lld %t %t2 -o %t3.out --icf=all --verbose | FileCheck --check-prefix=NOMERGE %s

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %S/Inputs/icf-merge3.s -o %t3
# RUN: ld.lld %t %t3 -o %t3.out --icf=all --verbose | FileCheck --check-prefix=NOMERGE %s

# CHECK: selected .text.f1
# CHECK:   removed .text.f2

# NOMERGE-NOT: selected .text.f

.section .rodata.str,"aMS",@progbits,1
foo:
.asciz "foo"
.asciz "string 1"
.asciz "string 2"

.section .text.f1,"ax"
.globl f1
f1:
lea foo+42(%rip), %rax
