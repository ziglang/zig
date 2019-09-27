# REQUIRES: x86
# RUN: llvm-mc --triple=x86_64-pc-linux --filetype=obj -o %t.o %s
# RUN: not ld.lld --pac-plt --force-bti %t.o -o %t 2>&1 | FileCheck %s
#
## Check that we error if --pac-plt and --force-bti are used when target is not
## aarch64

# CHECK: error: --pac-plt only supported on AArch64
# CHECK-NEXT: error: --force-bti only supported on AArch64

        .globl start
start:  ret
