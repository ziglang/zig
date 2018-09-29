; REQUIRES: x86
; RUN: llvm-as %s -o %t.o
; RUN: ld.lld %t.o %t.o -o %t.so -shared
; RUN: llvm-readobj -t %t.so | FileCheck %s

; CHECK:      Name: foo
; CHECK-NEXT: Value:
; CHECK-NEXT: Size: 1
; CHECK-NEXT: Binding: Global
; CHECK-NEXT: Type: Function
; CHECK-NEXT: Other: 0
; CHECK-NEXT: Section: .text

target triple = "x86_64-unknown-linux-gnu"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"

$foo = comdat any
define void @foo() comdat {
  ret void
}

