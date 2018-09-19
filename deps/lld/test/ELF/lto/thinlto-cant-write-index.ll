; REQUIRES: x86

; Basic ThinLTO tests.
; RUN: opt -module-summary %s -o %t1.o
; RUN: opt -module-summary %p/Inputs/thinlto.ll -o %t2.o

; Ensure lld generates error if unable to write to index files
; RUN: rm -f %t2.o.thinlto.bc
; RUN: touch %t2.o.thinlto.bc
; RUN: chmod 400 %t2.o.thinlto.bc
; RUN: not ld.lld --plugin-opt=thinlto-index-only -shared %t1.o %t2.o -o %t3 2>&1 | FileCheck %s
; CHECK: cannot open {{.*}}2.o.thinlto.bc: {{P|p}}ermission denied

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

declare void @g(...)

define void @f() {
entry:
  call void (...) @g()
  ret void
}
