# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld -shared -hash-style=gnu --no-rosegment -o %t.so %t.o
# RUN: llvm-readobj -gnu-hash-table %t.so | FileCheck %s

# CHECK:      GnuHashTable {
# CHECK-NEXT:   Num Buckets: 1
# CHECK-NEXT:   First Hashed Symbol Index: 1
# CHECK-NEXT:   Num Mask Words: 1
# CHECK-NEXT:   Shift Count: 6
# CHECK-NEXT:   Bloom Filter: [0x400000000004204]
# CHECK-NEXT:   Buckets: [1]
# CHECK-NEXT:   Values: [0xB8860BA, 0xB887389]
# CHECK-NEXT: }

.globl foo, bar
foo:
bar:
  ret
