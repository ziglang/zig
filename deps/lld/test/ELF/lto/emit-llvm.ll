; REQUIRES: x86

; RUN: opt -module-hash -module-summary %s -o %t.o
; RUN: ld.lld --plugin-opt=emit-llvm -o %t.out.o %t.o
; RUN: llvm-dis < %t.out.o -o - | FileCheck %s

; CHECK: define internal void @main()

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

define void @main() {
  ret void
}
