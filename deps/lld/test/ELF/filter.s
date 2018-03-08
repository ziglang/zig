# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: ld.lld %t.o -shared -F foo.so -F boo.so -o %t1
# RUN: llvm-readobj --dynamic-table %t1 | FileCheck %s

# Test alias #1.
# RUN: ld.lld %t.o -shared --filter=foo.so --filter=boo.so -o %t2
# RUN: llvm-readobj --dynamic-table %t2 | FileCheck %s

# Test alias #2.
# RUN: ld.lld %t.o -shared --filter foo.so --filter boo.so -o %t3
# RUN: llvm-readobj --dynamic-table %t3 | FileCheck %s

# CHECK:      DynamicSection [
# CHECK-NEXT: Tag                Type          Name/Value
# CHECK-NEXT: 0x000000007FFFFFFF FILTER        Filter library: [foo.so]
# CHECK-NEXT: 0x000000007FFFFFFF FILTER        Filter library: [boo.so]

# RUN: not ld.lld %t.o -F x -o %t 2>&1 | FileCheck -check-prefix=ERR %s
# ERR: -F may not be used without -shared
