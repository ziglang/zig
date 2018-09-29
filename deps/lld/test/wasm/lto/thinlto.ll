; Basic ThinLTO tests.
; RUN: opt -module-summary %s -o %t1.o
; RUN: opt -module-summary %p/Inputs/thinlto.ll -o %t2.o

; First force single-threaded mode
; RUN: rm -f %t31.lto.o %t32.lto.o
; RUN: wasm-ld -r -save-temps --thinlto-jobs=1 %t1.o %t2.o -o %t3
; RUN: llvm-nm %t31.lto.o | FileCheck %s --check-prefix=NM1
; RUN: llvm-nm %t32.lto.o | FileCheck %s --check-prefix=NM2

; Next force multi-threaded mode
; RUN: rm -f %t31.lto.o %t32.lto.o
; RUN: wasm-ld -r -save-temps --thinlto-jobs=2 %t1.o %t2.o -o %t3
; RUN: llvm-nm %t31.lto.o | FileCheck %s --check-prefix=NM1
; RUN: llvm-nm %t32.lto.o | FileCheck %s --check-prefix=NM2

; Check without --thinlto-jobs (which currently default to hardware_concurrency)
; RUN: wasm-ld -r %t1.o %t2.o -o %t3
; RUN: llvm-nm %t31.lto.o | FileCheck %s --check-prefix=NM1
; RUN: llvm-nm %t32.lto.o | FileCheck %s --check-prefix=NM2

; NM1: T f
; NM2: T g

target datalayout = "e-m:e-p:32:32-i64:64-n32:64-S128"
target triple = "wasm32-unknown-unknown"

declare void @g(...)

define void @f() {
entry:
  call void (...) @g()
  ret void
}
