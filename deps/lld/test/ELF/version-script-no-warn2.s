# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %p/Inputs/version-script-no-warn2.s -o %t1.o
# RUN: ld.lld %t1.o -o %t1.so -shared
# RUN: echo "{ global: foo; local:  *; };" > %t.script
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t2.o
# RUN: ld.lld -shared --version-script %t.script %t2.o %t1.so -o /dev/null --fatal-warnings

.global	foo
foo:
