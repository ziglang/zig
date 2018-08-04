; REQUIRES: x86
; RUN: llvm-as %s -o %t.o
; RUN: echo "{ global: foo; local: *; };" > %t.script
; RUN: ld.lld %t.o -o %t2 -shared --version-script %t.script -save-temps
; RUN: llvm-dis < %t2.0.2.internalize.bc | FileCheck %s

target triple = "x86_64-unknown-linux-gnu"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"

define void @foo() {
  ret void
}

define void @bar() {
  ret void
}

; Check that foo is not internalized.
; CHECK: define void @foo()

; Check that bar is correctly internalized.
; CHECK: define internal void @bar()
