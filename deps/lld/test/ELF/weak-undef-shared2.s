# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64 %s -o %t.o
# RUN: echo '.globl f; f:' | llvm-mc -filetype=obj -triple=x86_64 - -o %t1.o
# RUN: echo '.weak f; .data; .quad f' | llvm-mc -filetype=obj -triple=x86_64 - -o %t2.o
# RUN: ld.lld -shared %t1.o -o %t1.so
# RUN: ld.lld -shared %t2.o -o %t2.so

## The undefined reference is STB_GLOBAL in %t.o while STB_WEAK in %t2.so.
## Check the binding of the result is STB_GLOBAL.

# RUN: ld.lld %t.o %t1.so %t2.so -o %t
# RUN: llvm-readelf --dyn-syms %t | FileCheck %s
# RUN: ld.lld %t1.so %t.o %t2.so -o %t
# RUN: llvm-readelf --dyn-syms %t | FileCheck %s
# RUN: ld.lld %t1.so %t2.so %t.o -o %t
# RUN: llvm-readelf --dyn-syms %t | FileCheck %s

# CHECK: NOTYPE GLOBAL DEFAULT UND f

.data
.quad f
