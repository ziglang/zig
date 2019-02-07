# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-pc-linux %s -o %t.o
# RUN: echo "{ local: *; };" > %t.list
# RUN: not ld.lld -dynamic-list %t.list -shared %t.o -o %t.so 2>&1 | FileCheck %s

# CHECK: error: {{.*}}:1: "local:" scope not supported in --dynamic-list
