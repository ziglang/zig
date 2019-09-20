; TLS attribute needs to be preserved.
; REQUIRES: x86
; RUN: llvm-as %s -o %t1.o
; RUN: ld.lld -shared %t1.o -o %t1
; RUN: llvm-readobj --symbols %t1 | FileCheck %s

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

@tsp_int = thread_local global i32 1

define void @_start() {
  %val = load i32, i32* @tsp_int
  ret void
}

; CHECK: Symbol {
; CHECK:   Name: tsp_int
; CHECK-NEXT:   Value: 0x0
; CHECK-NEXT:   Size: 4
; CHECK-NEXT:   Binding: Global
; CHECK-NEXT:   Type: TLS
; CHECK-NEXT:   Other: 0
; CHECK-NEXT:   Section: .tdata
; CHECK-NEXT: }
