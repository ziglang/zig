# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: not ld.lld %t.o -o %t.so -shared 2>&1 | FileCheck %s

# CHECK: error: undefined symbol: hidden
# CHECK: >>> referenced by {{.*}}:(.data+0x0)
.global hidden
.hidden hidden

# CHECK: error: undefined symbol: internal
# CHECK: >>> referenced by {{.*}}:(.data+0x8)
.global internal
.internal internal

# CHECK: error: undefined symbol: protected
# CHECK: >>> referenced by {{.*}}:(.data+0x10)
.global protected
.protected protected

.section .data, "a"
 .quad hidden
 .quad internal
 .quad protected
