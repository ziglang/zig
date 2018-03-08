# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t1.o
# RUN: ld.lld -o %t2.o -r %t1.o
# RUN: llvm-nm %t2.o | FileCheck %s
# CHECK: foo@VERSION

.global "foo@VERSION"
"foo@VERSION":
  ret
