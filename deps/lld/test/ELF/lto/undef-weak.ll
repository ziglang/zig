; REQUIRES: x86
; RUN: llvm-as %S/Inputs/archive.ll -o %t1.o
; RUN: rm -f %t.a
; RUN: llvm-ar rcs %t.a %t1.o

; RUN: llvm-as %s -o %t2.o
; RUN: ld.lld %t2.o -o %t2.so %t.a -shared
; RUN: llvm-readobj --symbols %t2.so | FileCheck %s

target triple = "x86_64-unknown-linux-gnu"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"

declare extern_weak void @f()
define void @foo() {
  call void @f()
  ret void
}

; We should not fetch the archive member.

; CHECK:      Name: f ({{.*}})
; CHECK-NEXT: Value: 0x0
; CHECK-NEXT: Size: 0
; CHECK-NEXT: Binding: Weak
; CHECK-NEXT: Type: None
; CHECK-NEXT: Other: 0
; CHECK-NEXT: Section: Undefined

