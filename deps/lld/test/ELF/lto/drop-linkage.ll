target triple = "x86_64-unknown-linux-gnu"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"

; REQUIRES: x86
; RUN: llc %s -o %t.o -filetype=obj
; RUN: llvm-as %p/Inputs/drop-linkage.ll -o %t2.o
; RUN: ld.lld %t.o %t2.o -o %t.so -save-temps -shared
; RUN: llvm-dis %t.so.0.4.opt.bc -o - | FileCheck %s

define void @foo() {
  ret void
}

; CHECK: declare void @foo()
