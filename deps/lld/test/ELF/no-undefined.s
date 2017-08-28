# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: not ld.lld --no-undefined -shared %t -o %t.so
# RUN: ld.lld -shared %t -o %t1.so

.globl _shared
_shared:
  callq _unresolved@PLT
