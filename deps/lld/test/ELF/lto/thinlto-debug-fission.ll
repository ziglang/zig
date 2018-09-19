; REQUIRES: x86

; RUN: opt %s -o %t1.o
; RUN: rm -rf %T/dwo

; Test to ensure that --plugin-opt=dwo_dir=$DIR creates .dwo files under $DIR
; RUN: ld.lld --plugin-opt=dwo_dir=%T/dwo -shared %t1.o -o /dev/null
; RUN: llvm-readobj -h %T/dwo/0.dwo | FileCheck %s

; CHECK: Format: ELF64-x86-64

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

declare void @g(...)

define void @f() {
entry:
  call void (...) @g()
  ret void
}
