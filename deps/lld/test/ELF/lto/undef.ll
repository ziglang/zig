; REQUIRES: x86
; RUN: llvm-as %s -o %t.o
; RUN: ld.lld %t.o -o %t.so -shared
; RUN: llvm-readobj --symbols %t.so | FileCheck %s
target triple = "x86_64-unknown-linux-gnu"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"

declare void @bar()
define void @foo() {
  call void @bar()
  ret void
}

; CHECK:      Name: bar
; CHECK-NEXT: Value: 0x0
; CHECK-NEXT: Size: 0
; CHECK-NEXT: Binding: Global
; CHECK-NEXT: Type: None
; CHECK-NEXT: Other: 0
; CHECK-NEXT: Section: Undefined
