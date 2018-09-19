; REQUIRES: x86
; RUN: llvm-as %s -o %t.bc
; RUN: not wasm-ld %t.bc -o out.wasm 2>&1 | FileCheck %s

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

; CHECK: {{.*}}incompatible.ll.tmp.bc: machine type must be wasm32
