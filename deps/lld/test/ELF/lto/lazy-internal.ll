; REQUIRES: x86
; RUN: llvm-as %s -o %t1.o
; RUN: llvm-as %p/Inputs/lazy-internal.ll -o %t2.o
; RUN: rm -f %t2.a
; RUN: llvm-ar rc %t2.a %t2.o
; RUN: ld.lld %t2.a %t1.o -o %t.so -shared -save-temps
; RUN: llvm-dis %t.so.0.2.internalize.bc -o - | FileCheck %s

; CHECK: define internal void @foo()
; CHECK: define internal void @bar()

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

define hidden void @foo() {
  call void @bar()
  ret void
}
declare void @bar()
