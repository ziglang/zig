# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld -shared --no-rosegment -o %t %t.o
# RUN: llvm-readobj --hash-table %t | FileCheck %s

# CHECK:      HashTable {
# CHECK-NEXT:   Num Buckets: 2
# CHECK-NEXT:   Num Chains: 2
# CHECK-NEXT:   Buckets: [1, 0]
# CHECK-NEXT:   Chains: [0, 0]
# CHECK-NEXT: }

callq undef@PLT
