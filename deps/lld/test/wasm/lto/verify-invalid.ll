; RUN: llvm-as %s -o %t.o
; RUN: wasm-ld %t.o -o %t2 -mllvm -debug-pass=Arguments \
; RUN:   2>&1 | FileCheck -check-prefix=DEFAULT %s
; RUN: wasm-ld %t.o -o %t2 -mllvm -debug-pass=Arguments \
; RUN:   -disable-verify 2>&1 | FileCheck -check-prefix=DISABLE %s

target datalayout = "e-m:e-p:32:32-i64:64-n32:64-S128"
target triple = "wasm32-unknown-unknown"

define void @_start() {
  ret void
}

; -disable-verify should disable the verification of bitcode.
; DEFAULT:     Pass Arguments: {{.*}} -verify {{.*}} -verify
; DISABLE-NOT: Pass Arguments: {{.*}} -verify {{.*}} -verify
