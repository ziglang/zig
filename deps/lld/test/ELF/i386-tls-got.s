# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=i386-pc-linux %S/Inputs/i386-tls-got.s -o %t1.o
# RUN: ld.lld %t1.o -o %t1.so -shared
# RUN: llvm-mc -filetype=obj -triple=i386-pc-linux %s -o %t2.o
# RUN: ld.lld %t2.o %t1.so -o %t

	addl	foobar@INDNTPOFF, %eax
