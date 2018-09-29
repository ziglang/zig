; RUN: llvm-as %s -o %t.o
; RUN: wasm-ld %t.o -o %t2 -save-temps
; RUN: llvm-dis < %t2.0.2.internalize.bc | FileCheck %s

target datalayout = "e-m:e-p:32:32-i64:64-n32:64-S128"
target triple = "wasm32-unknown-unknown-wasm"

define void @_start() {
  ret void
}

define hidden void @foo() {
  ret void
}

; Check that _start is not internalized.
; CHECK: define void @_start()

; Check that foo function is correctly internalized.
; CHECK: define internal void @foo()
