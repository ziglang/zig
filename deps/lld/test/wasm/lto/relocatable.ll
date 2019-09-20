; RUN: llvm-as %s -o %t1.o
; RUN: wasm-ld %t1.o -r -o %t
; RUN: llvm-readobj --symbols %t | FileCheck %s

; CHECK:      Symbols [
; CHECK-NEXT:   Symbol {
; CHECK-NEXT:     Name: foo
; CHECK-NEXT:     Type: FUNCTION (0x0)
; CHECK-NEXT:     Flags [ (0x0)
; CHECK-NEXT:     ]
; CHECK-NEXT:     ElementIndex: 0x0
; CHECK-NEXT:   }
; CHECK-NEXT: ]

target datalayout = "e-m:e-p:32:32-i64:64-n32:64-S128"
target triple = "wasm32-unknown-unknown"

define void @foo() {
  call void @bar()
  ret void
}

define internal void @bar() {
  ret void
}

declare i32 @baz(...)
