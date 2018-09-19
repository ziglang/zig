; REQUIRES: x86

; Basic ThinLTO tests.
; RUN: opt -module-summary %s -o %t1.o
; RUN: opt -module-summary %p/Inputs/thinlto.ll -o %t2.o

; First force single-threaded mode
; RUN: rm -f %t31.lto.o %t32.lto.o
; RUN: ld.lld -save-temps --thinlto-jobs=1 -shared %t1.o %t2.o -o %t3
; RUN: llvm-nm %t31.lto.o | FileCheck %s --check-prefix=NM1
; RUN: llvm-nm %t32.lto.o | FileCheck %s --check-prefix=NM2

; Next force multi-threaded mode
; RUN: rm -f %t31.lto.o %t32.lto.o
; RUN: ld.lld -save-temps --thinlto-jobs=2 -shared %t1.o %t2.o -o %t3
; RUN: llvm-nm %t31.lto.o | FileCheck %s --check-prefix=NM1
; RUN: llvm-nm %t32.lto.o | FileCheck %s --check-prefix=NM2

; Then check without --thinlto-jobs (which currently default to hardware_concurrency)
; RUN: ld.lld -shared %t1.o %t2.o -o %t3
; RUN: llvm-nm %t31.lto.o | FileCheck %s --check-prefix=NM1
; RUN: llvm-nm %t32.lto.o | FileCheck %s --check-prefix=NM2

; NM1: T f
; NM2: T g

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

declare void @g(...)

define void @f() {
entry:
  call void (...) @g()
  ret void
}
