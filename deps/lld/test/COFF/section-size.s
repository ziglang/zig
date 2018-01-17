# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-windows-msvc %s -o %tmain.obj
# RUN: echo '.lcomm s, 0x80000000' | llvm-mc -filetype=obj -triple=x86_64-windows-msvc -o %t1.obj
# RUN: cp %t1.obj %t2.obj
# RUN: echo '.lcomm s, 0xffffffff' | llvm-mc -filetype=obj -triple=x86_64-windows-msvc -o %t3.obj

# Run: lld-link -entry:main %tmain.obj %t3.obj -out:%t.exe

# RUN: not lld-link -entry:main %tmain.obj %t1.obj %t2.obj -out:%t.exe 2>&1 | FileCheck %s
# CHECK: error: section larger than 4 GiB: .bss

.globl main
main:
	retq
