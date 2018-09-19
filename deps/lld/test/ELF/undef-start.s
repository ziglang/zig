# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t.o
# RUN: ld.lld %t.o -o /dev/null 2>&1 | FileCheck %s

# CHECK: warning: cannot find entry symbol _start
