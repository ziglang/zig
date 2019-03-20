# REQUIRES: x86, zlib
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: ld.lld %t -o %t2 --strip-debug
# RUN: llvm-readobj -sections %t2 | FileCheck %s
# RUN: ld.lld %t -o %t2 -S
# RUN: llvm-readobj -sections %t2 | FileCheck %s
# RUN: ld.lld %t -o %t2 --strip-all
# RUN: llvm-readobj -sections %t2 | FileCheck %s

# CHECK-NOT: Foo
# CHECK-NOT: Bar

.section .debug_Foo,"",@progbits
.section .zdebug_Bar,"",@progbits
.ascii "ZLIB"
.quad 0
