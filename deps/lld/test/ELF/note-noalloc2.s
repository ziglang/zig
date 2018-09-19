# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld %t.o -o %t
# RUN: llvm-readobj -program-headers %t | FileCheck %s

## Check we do not create a PT_NOTE segment for non-allocatable note section.

# CHECK-NOT:  PT_NOTE

.section  .note,"",@note
.quad 0
