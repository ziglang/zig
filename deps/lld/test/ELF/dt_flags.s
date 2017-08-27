# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: ld.lld -shared %t -o %t.so
# RUN: ld.lld -z now -z nodelete -z nodlopen -z origin -Bsymbolic %t %t.so -o %t1
# RUN: ld.lld %t %t.so -o %t2
# RUN: llvm-readobj -dynamic-table %t1 | FileCheck -check-prefix=FLAGS %s
# RUN: llvm-readobj -dynamic-table %t2 | FileCheck %s

# FLAGS: DynamicSection [
# FLAGS:   0x000000000000001E FLAGS ORIGIN SYMBOLIC BIND_NOW
# FLAGS:   0x000000006FFFFFFB FLAGS_1 NOW NODELETE NOOPEN ORIGIN
# FLAGS: ]

# CHECK: DynamicSection [
# CHECK-NOT:   0x000000000000001E FLAGS ORIGIN SYMBOLIC BIND_NOW
# CHECK-NOT:   0x000000006FFFFFFB FLAGS_1 NOW NODELETE NOOPEN ORIGIN
# CHECK: ]

.globl _start
_start:
