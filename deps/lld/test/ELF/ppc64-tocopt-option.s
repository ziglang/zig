# REQUIRES: x86

# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: not ld.lld %t --toc-optimize -o /dev/null 2>&1 | FileCheck %s

# CHECK: error: --toc-optimize is only supported on the PowerPC64 target

         .global __start
         .type __start,@function

         .text
        .quad 0
 __start:

