; REQUIRES: x86
; RUN: llvm-as %s -o %t.o
; RUN: echo ".global __progname; .data; .dc.a __progname" > %t2.s
; RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux %t2.s -o %t2.o
; RUN: ld.lld -shared %t2.o -o %t2.so
; RUN: ld.lld -o %t %t.o %t2.so
; RUN: llvm-readobj --dyn-syms %t | FileCheck %s

; CHECK:      Name:     __progname
; CHECK-NEXT: Value:    0x201010
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

define void @__progname() {
  ret void
}
