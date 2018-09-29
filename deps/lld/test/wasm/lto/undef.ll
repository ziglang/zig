; RUN: llvm-as %s -o %t.o
; RUN: wasm-ld %t.o -o %t.wasm --allow-undefined
; RUN: obj2yaml %t.wasm | FileCheck %s

target datalayout = "e-m:e-p:32:32-i64:64-n32:64-S128"
target triple = "wasm32-unknown-unknown"

declare void @bar()

define void @_start() {
  call void @bar()
  ret void
}

; CHECK:       - Type:            IMPORT
; CHECK-NEXT:    Imports:         
; CHECK-NEXT:      - Module:          env
; CHECK-NEXT:        Field:           bar
; CHECK-NEXT:        Kind:            FUNCTION
; CHECK-NEXT:        SigIndex:        0
