; REQUIRES: x86
; Basic ThinLTO tests.
; RUN: opt -module-summary %s -o %t.o
; RUN: opt -module-summary %p/Inputs/thinlto.ll -o %t2.o

; First force single-threaded mode
; RUN: rm -f %t.lto.o %t1.lto.o
; RUN: ld.lld -save-temps --thinlto-jobs=1 -shared %t.o %t2.o -o %t
; RUN: llvm-nm %t1.lto.o | FileCheck %s --check-prefix=NM1
; RUN: llvm-nm %t2.lto.o | FileCheck %s --check-prefix=NM2

; Next force multi-threaded mode
; RUN: rm -f %t2.lto.o %t21.lto.o
; RUN: ld.lld -save-temps --thinlto-jobs=2 -shared %t.o %t2.o -o %t2
; RUN: llvm-nm %t21.lto.o | FileCheck %s --check-prefix=NM1
; RUN: llvm-nm %t22.lto.o | FileCheck %s --check-prefix=NM2

; NM1: T f
; NM1-NOT: U g

; NM2: T g

; Then check without --thinlto-jobs (which currently default to hardware_concurrency)
; We just check that we don't crash or fail (as it's not sure which tests are
; stable on the final output file itself.
; RUN: ld.lld -shared %t.o %t2.o -o %t2

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

declare void @g(...)

define void @f() {
entry:
  call void (...) @g()
  ret void
}
