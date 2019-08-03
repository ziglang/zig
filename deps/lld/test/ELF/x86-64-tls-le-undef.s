# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64 %s -o %t.o
# RUN: ld.lld --noinhibit-exec %t.o -o %t 2>&1
# RUN: llvm-objdump -d %t | FileCheck %s

## Undefined TLS symbols resolve to 0.
## In --noinhibit-exec mode, a non-weak undefined symbol is not an error.

# CHECK:      leaq 16(%rax), %rdx
# CHECK-NEXT: leaq 32(%rax), %rdx

.weak weak
movq %fs:0, %rax
leaq weak@tpoff+16(%rax), %rdx
leaq global@tpoff+32(%rax), %rdx
