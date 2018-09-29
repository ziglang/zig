; REQUIRES: x86
; RUN: llvm-as %s -o %t.o
; RUN: llvm-as %p/Inputs/type-merge.ll -o %t2.o
; RUN: ld.lld %t.o %t2.o -o %t -shared -save-temps
; RUN: llvm-dis < %t.0.0.preopt.bc | FileCheck %s

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

define void @foo()  {
  call void @bar(i8* null)
  ret void
}
declare void @bar(i8*)

; CHECK:      define void @foo() {
; CHECK-NEXT:   call void @bar(i8* null)
; CHECK-NEXT:   ret void
; CHECK-NEXT: }

; CHECK: declare void @bar(i8*)

; CHECK:      define void @zed() {
; CHECK-NEXT:   call void bitcast (void (i8*)* @bar to void ()*)()
; CHECK-NEXT:   ret void
; CHECK-NEXT: }
