# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: echo "SECTIONS { zed : ONLY_IF_RO { *(foo) *(bar) } }" > %t.script
# RUN: ld.lld -T %t.script %t.o -o %t.so -shared
# RUN: llvm-readobj -s %t.so | FileCheck %s

# CHECK: Sections [
# CHECK-NOT: zed

.section foo,"aw"
.quad 1

.section bar, "a"
.quad 2
