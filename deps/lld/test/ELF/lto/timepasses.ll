; REQUIRES: x86
; RUN: llvm-as %s -o %t.o
; RUN: env LLD_IN_TEST=0 ld.lld %t.o -o %t.so -shared -mllvm \
; RUN:   -time-passes 2>&1 | FileCheck %s

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

define void @patatino() {
  ret void
}

; We should get the output of -time-passes even when full shutdown is not specified.
; CHECK: Total Execution Time
