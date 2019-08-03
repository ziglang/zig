# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t1.o
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/wrap-dynamic-undef.s -o %t2.o
# RUN: ld.lld %t2.o -o %t2.so -shared
# RUN: ld.lld %t1.o %t2.so -o %t --wrap foo
# RUN: llvm-readelf --dyn-syms %t | FileCheck %s

# Test that the dynamic relocation uses foo. We used to produce a
# relocation with __real_foo.

# CHECK: NOTYPE  GLOBAL DEFAULT UND foo

.global _start
_start:
	callq	__real_foo@plt
