# REQUIRES: x86
# RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %s -o %t
# RUN: not ld.lld %t -o %tout --unresolved-symbols=ignore-all -pie 2>&1 | FileCheck %s
# CHECK: error: undefined symbol: foo

.protected foo
_start:
callq foo@PLT
