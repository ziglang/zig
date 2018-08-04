; REQUIRES: x86
; RUN: llvm-as %s -o %t.o
; RUN: ld.lld %t.o %t.o -o %t.so -shared
; RUN: llvm-readobj -t %t.so | FileCheck %s

target triple = "x86_64-unknown-linux-gnu"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"

define weak void @f() {
  ret void
}

; CHECK:      Name: f
; CHECK-NEXT: Value: 0x1000
; CHECK-NEXT: Size: 1
; CHECK-NEXT: Binding: Weak
