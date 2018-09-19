; REQUIRES: x86
; RUN: llvm-as %s -o %t1.o
; RUN: llvm-mc -triple=x86_64-pc-linux %p/Inputs/visibility.s -o %t2.o -filetype=obj
; RUN: ld.lld %t1.o %t2.o -o %t.so -shared -save-temps
; RUN: llvm-dis < %t.so.0.2.internalize.bc | FileCheck --check-prefix=IR %s
; RUN: llvm-readobj -t %t.so | FileCheck %s

; CHECK:      Name: g
; CHECK-NEXT: Value: 0x1000
; CHECK-NEXT: Size: 0
; CHECK-NEXT: Binding: Local
; CHECK-NEXT: Type: None
; CHECK-NEXT: Other [ (0x2)
; CHECK-NEXT:   STV_HIDDEN
; CHECK-NEXT: ]
; CHECK-NEXT: Section: .text

; CHECK:      Name: a
; CHECK-NEXT: Value: 0x2000
; CHECK-NEXT: Size: 0
; CHECK-NEXT: Binding: Local
; CHECK-NEXT: Type: None
; CHECK-NEXT: Other [ (0x2)
; CHECK-NEXT:   STV_HIDDEN
; CHECK-NEXT: ]
; CHECK-NEXT: Section: .data

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

declare hidden void @g()
; IR: declare hidden void @g()

define void @f() {
  call void @g()
  ret void
}
@a = weak hidden global i32 42
