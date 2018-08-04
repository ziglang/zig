; REQUIRES: x86

; RUN: opt -module-summary %s -o %t1.o
; RUN: opt -module-summary %p/Inputs/thinlto.ll -o %t2.o

; Test to ensure that thinlto-index-only with obj-path creates the file.
; RUN: rm -f %t4.o
; RUN: ld.lld --plugin-opt=thinlto-index-only --plugin-opt=obj-path=%t4.o -shared %t1.o %t2.o -o %t3
; RUN: llvm-readobj -h %t4.o | FileCheck %s
; RUN: llvm-nm %t4.o | count 0

; CHECK: Format: ELF64-x86-64

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

declare void @g(...)

define void @f() {
entry:
  call void (...) @g()
  ret void
}
