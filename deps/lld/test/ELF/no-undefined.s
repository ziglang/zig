# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: not ld.lld --no-undefined -shared %t -o /dev/null
# RUN: ld.lld -shared %t -o /dev/null

.globl _shared
_shared:
  callq _unresolved@PLT
