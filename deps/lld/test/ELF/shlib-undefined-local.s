# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-linux-gnu -o %t1.o %S/Inputs/shlib-undefined-ref.s
# RUN: ld.lld -shared -o %t.so %t1.o

# RUN: llvm-mc -filetype=obj -triple=x86_64-linux-gnu -o %t2.o %s
# RUN: echo "{ local: *; };" > %t.script
# RUN: ld.lld -version-script %t.script -o %t %t2.o %t.so
# RUN: llvm-nm -g %t | FileCheck -allow-empty %s

# CHECK-NOT: should_not_be_exported

.globl should_not_be_exported
should_not_be_exported:
	ret

.globl _start
_start:
	ret
