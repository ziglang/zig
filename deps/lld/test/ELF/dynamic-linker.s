# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/shared.s -o %t1.o
# RUN: ld.lld -shared %t1.o -o %t.so
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o

# RUN: ld.lld --dynamic-linker foo %t.o %t.so -o %t
# RUN: llvm-readelf -program-headers %t | FileCheck %s

# RUN: ld.lld --dynamic-linker=foo %t.o %t.so -o %t
# RUN: llvm-readelf -program-headers %t | FileCheck %s

# CHECK: [Requesting program interpreter: foo]

# RUN: ld.lld %t.o %t.so -o %t
# RUN: llvm-readelf -program-headers %t | FileCheck --check-prefix=NO %s

# RUN: ld.lld --dynamic-linker foo --no-dynamic-linker %t.o %t.so -o %t
# RUN: llvm-readelf -program-headers %t | FileCheck --check-prefix=NO %s

# NO-NOT: PT_INTERP

.globl _start
_start:
  nop
