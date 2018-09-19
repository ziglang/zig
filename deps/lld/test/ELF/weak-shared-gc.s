# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t1.o
# RUN: echo -e '.globl __cxa_finalize\n__cxa_finalize:' | \
# RUN:   llvm-mc -filetype=obj -triple=x86_64-pc-linux - -o %t2.o
# RUN: ld.lld %t2.o -o %t2.so -shared
# RUN: ld.lld %t1.o --as-needed --gc-sections %t2.so -o %t
# RUN: llvm-readelf -dynamic-table -dyn-symbols %t | FileCheck %s

# The crt files on linux have a weak reference to __cxa_finalize. It
# is important that a weak undefined reference is produced. Like
# other weak undefined references, the shared library is not marked as
# needed.

# CHECK-NOT: NEEDED
# CHECK: WEAK   DEFAULT UND __cxa_finalize
# CHECK-NOT: NEEDED

        .global _start
_start:
	.weak	__cxa_finalize
	call	__cxa_finalize@PLT
