; REQUIRES: x86
; RUN: opt -module-summary %s -o %t1.o
; RUN: opt -module-summary %p/Inputs/thinlto.ll -o %t2.o

; RUN: rm -f %t1.lto.o %t2.lto.o
; RUN: ld.lld --lto-sample-profile=%p/Inputs/sample-profile.prof %t1.o %t2.o -o %t3
; RUN  opt -S %t3.lto.o | FileCheck %s

; RUN: rm -f %t1.lto.o %t2.lto.o
; RUN: ld.lld --plugin-opt=sample-profile=%p/Inputs/sample-profile.prof %t1.o %t2.o -o %t3
; RUN  opt -S %t3.lto.o | FileCheck %s

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

; CHECK: ProfileSummary
declare void @g(...)
declare void @h(...)

define void @f() {
entry:
  call void (...) @g()
  call void (...) @h()
  ret void
}
