; RUN: cd %T
; RUN: rm -f a.out a.out.lto.bc a.out.lto.o
; RUN: llvm-as %s -o %t.o
; RUN: llvm-as %p/Inputs/save-temps.ll -o %t2.o
; RUN: wasm-ld -r -o a.out %t.o %t2.o -save-temps
; RUN: llvm-nm a.out | FileCheck %s
; RUN: llvm-nm a.out.0.0.preopt.bc | FileCheck %s
; RUN: llvm-nm a.out.lto.o | FileCheck %s
; RUN: llvm-dis a.out.0.0.preopt.bc

target datalayout = "e-m:e-p:32:32-i64:64-n32:64-S128"
target triple = "wasm32-unknown-unknown"

define void @foo() {
  ret void
}

; CHECK: T bar
; CHECK: T foo
