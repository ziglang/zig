; REQUIRES: x86

; Basic ThinLTO tests.
; RUN: opt -module-summary %s -o %t1.o
; RUN: opt -module-summary %p/Inputs/thinlto.ll -o %t2.o
; RUN: opt -module-summary %p/Inputs/thinlto_empty.ll -o %t3.o

; Ensure lld doesn't generates index files when thinlto-index-only is not enabled
; RUN: rm -f %t1.o.thinlto.bc %t2.o.thinlto.bc %t3.o.thinlto.bc
; RUN: ld.lld -shared %t1.o %t2.o %t3.o -o %t4
; RUN: not ls %t1.o.thinlto.bc
; RUN: not ls %t2.o.thinlto.bc
; RUN: not ls %t3.o.thinlto.bc

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

declare void @g(...)

define void @f() {
entry:
  call void (...) @g()
  ret void
}
