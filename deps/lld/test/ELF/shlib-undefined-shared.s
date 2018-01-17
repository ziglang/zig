# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-linux-gnu -o %t1.o %S/Inputs/shlib-undefined-ref.s
# RUN: ld.lld -shared -o %t1.so %t1.o

# RUN: llvm-mc -filetype=obj -triple=x86_64-linux-gnu -o %t2.o %s
# RUN: echo "{ local: *; };" > %t.script
# RUN: ld.lld -shared -version-script %t.script -o %t2.so %t2.o %t1.so
# RUN: llvm-nm -g %t2.so | FileCheck -allow-empty %s

# CHECK-NOT: should_not_be_exported

.globl should_not_be_exported
should_not_be_exported:
	ret
