; RUN: llvm-as %S/Inputs/archive.ll -o %t1.o
; RUN: rm -f %t.a
; RUN: llvm-ar rcs %t.a %t1.o
; RUN: llvm-as %s -o %t2.o
; RUN: wasm-ld %t2.o %t.a -o %t3
; RUN: obj2yaml %t3 | FileCheck %s

target datalayout = "e-m:e-p:32:32-i64:64-n32:64-S128"
target triple = "wasm32-unknown-unknown"

define void @_start() {
  call void @f()
  ret void
}

declare void @f()

; CHECK:         Name:            name
; CHECK-NEXT:    FunctionNames:
; CHECK-NEXT:      - Index:           0
; CHECK-NEXT:        Name:            __wasm_call_ctors
; CHECK-NEXT:      - Index:           1
; CHECK-NEXT:        Name:            _start
; CHECK-NEXT:      - Index:           2
; CHECK-NEXT:        Name:            f
