# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: echo "SECTIONS { zed : ONLY_IF_RO { abc = 1; *(foo) } }" > %t.script
# RUN: ld.lld -T %t.script %t.o -o %t.so -shared
# RUN: llvm-readobj --symbols %t.so | FileCheck %s

# CHECK: Symbols [
# CHECK-NOT: abc

.section foo,"aw"
.quad 1
