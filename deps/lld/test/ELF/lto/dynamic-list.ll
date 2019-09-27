; REQUIRES: x86
; RUN: llvm-as %s -o %t.o
; RUN: echo "{ foo; };" > %t.list
; RUN: ld.lld -o %t --dynamic-list %t.list -pie %t.o
; RUN: llvm-readobj --dyn-syms %t | FileCheck %s

; CHECK:      Name:     foo
; CHECK-NEXT: Value:    0x1010
; CHECK-NEXT: Size:     1
; CHECK-NEXT: Binding:  Global (0x1)
; CHECK-NEXT: Type:     Function
; CHECK-NEXT: Other:    0
; CHECK-NEXT: Section:  .text
; CHECK-NEXT: }

target triple = "x86_64-unknown-linux-gnu"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"

define void @_start() {
  ret void
}

define void @foo() {
  ret void
}
