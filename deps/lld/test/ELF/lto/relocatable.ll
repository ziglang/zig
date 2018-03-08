; REQUIRES: x86
; RUN: llvm-as %s -o %t1.o
; RUN: ld.lld %t1.o -r -o %t
; RUN: llvm-readobj -symbols %t | FileCheck %s

; CHECK:       Symbols [
; CHECK-NEXT:   Symbol {
; CHECK-NEXT:     Name:
; CHECK-NEXT:     Value: 0x0
; CHECK-NEXT:     Size: 0
; CHECK-NEXT:     Binding: Local
; CHECK-NEXT:     Type: None
; CHECK-NEXT:     Other: 0
; CHECK-NEXT:     Section: Undefined
; CHECK-NEXT:   }
; CHECK-NEXT:   Symbol {
; CHECK-NEXT:     Name:
; CHECK-NEXT:     Value: 0x0
; CHECK-NEXT:     Size: 0
; CHECK-NEXT:     Binding: Local
; CHECK-NEXT:     Type: Section
; CHECK-NEXT:     Other: 0
; CHECK-NEXT:     Section: .text
; CHECK-NEXT:   }
; CHECK-NEXT:   Symbol {
; CHECK-NEXT:     Name:
; CHECK-NEXT:     Value: 0x0
; CHECK-NEXT:     Size: 0
; CHECK-NEXT:     Binding: Local
; CHECK-NEXT:     Type: Section
; CHECK-NEXT:     Other: 0
; CHECK-NEXT:     Section: .text.foo
; CHECK-NEXT:   }
; CHECK-NEXT:   Symbol {
; CHECK-NEXT:     Name: foo
; CHECK-NEXT:     Value: 0x0
; CHECK-NEXT:     Size: 1
; CHECK-NEXT:     Binding: Global
; CHECK-NEXT:     Type: Function
; CHECK-NEXT:     Other: 0
; CHECK-NEXT:     Section: .text.foo
; CHECK-NEXT:   }
; CHECK-NEXT: ]

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

define void @foo() {
  call void @bar()
  ret void
}

define internal void @bar() {
  ret void
}
