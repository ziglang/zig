# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=i386 %s -o %t.o
# RUN: ld.lld --noinhibit-exec %t.o -o %t 2>&1
# RUN: llvm-objdump -d %t | FileCheck %s

## Undefined TLS symbols resolve to 0.
## In --noinhibit-exec mode, a non-weak undefined symbol is not an error.

# CHECK: subl $0, %eax
# CHECK: subl $0, %eax

.weak weak_undef
movl %gs:0, %eax
subl $weak_undef@tpoff,%eax
movl %gs:0, %eax
subl $undef@tpoff,%eax
