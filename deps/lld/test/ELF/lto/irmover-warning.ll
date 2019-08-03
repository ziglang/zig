; REQUIRES: x86
; RUN: llvm-as -o %t1.bc %s
; RUN: llvm-as -o %t2.bc %S/Inputs/irmover-warning.ll
; RUN: rm -f %t.a
; RUN: llvm-ar rcs %t.a %t2.bc
; RUN: ld.lld %t1.bc %t.a -o %t 2>&1 | FileCheck %s

; CHECK: warning: linking module flags 'foo': IDs have conflicting values
; CHECK-SAME: irmover-warning.ll.tmp.a(irmover-warning.ll.tmp2.bc at {{[0-9]+}})

target triple = "x86_64-unknown-linux-gnu"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"

declare void @f()

define void @g() {
  call void @f()
  ret void
}

!0 = !{ i32 2, !"foo", i32 1 }

!llvm.module.flags = !{ !0 }
