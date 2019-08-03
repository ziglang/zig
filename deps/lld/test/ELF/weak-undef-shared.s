# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64 %s -o %t.o
# RUN: ld.lld -shared %t.o -o %t.so

# RUN: echo '.data; .weak foo; .quad foo' | llvm-mc -filetype=obj -triple=x86_64 - -o %t1.o
# RUN: echo '.data; .quad foo' | llvm-mc -filetype=obj -triple=x86_64 - -o %t2.o
# RUN: ld.lld -shared %t2.o -o %t2.so

## If the first undefined reference is weak, the binding changes to
## STB_WEAK.
# RUN: ld.lld %t1.o %t.so -o %t
# RUN: llvm-readelf --dyn-syms %t | FileCheck --check-prefix=WEAK %s
# RUN: ld.lld %t.so %t1.o -o %t
# RUN: llvm-readelf --dyn-syms %t | FileCheck --check-prefix=WEAK %s

## The binding remains STB_WEAK if there is no STB_GLOBAL undefined reference.
# RUN: ld.lld %t1.o %t.so %t1.o -o %t
# RUN: llvm-readelf --dyn-syms %t | FileCheck --check-prefix=WEAK %s
# RUN: ld.lld %t.so %t1.o %t1.o -o %t
# RUN: llvm-readelf --dyn-syms %t | FileCheck --check-prefix=WEAK %s

## The binding changes back to STB_GLOBAL if there is a STB_GLOBAL undefined reference.
# RUN: ld.lld %t1.o %t.so %t2.o -o %t
# RUN: llvm-readelf --dyn-syms %t | FileCheck --check-prefix=GLOBAL %s
# RUN: ld.lld %t2.o %t.so %t1.o -o %t
# RUN: llvm-readelf --dyn-syms %t | FileCheck --check-prefix=GLOBAL %s

## Check the binding (weak) is not affected by the STB_GLOBAL undefined
## reference in %t2.so
# RUN: ld.lld %t1.o %t2.so -o %t
# RUN: llvm-readelf --dyn-syms %t | FileCheck --check-prefix=WEAK %s

# WEAK:   NOTYPE WEAK   DEFAULT UND foo
# GLOBAL: NOTYPE GLOBAL DEFAULT UND foo

.globl foo
foo:
