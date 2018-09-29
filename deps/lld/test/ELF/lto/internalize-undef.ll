; REQUIRES: x86
; RUN: llvm-as %s -o %t.o
; RUN: llvm-as %p/Inputs/internalize-undef.ll -o %t2.o
; RUN: ld.lld %t.o %t2.o -o %t -save-temps
; RUN: llvm-dis < %t.0.2.internalize.bc | FileCheck %s

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

declare void @f()
define void @_start() {
  call void @f()
  ret void
}

; CHECK: define internal void @f()
