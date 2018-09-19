; RUN: llvm-as %s -o %t.o
; RUN: wasm-ld %t.o %t.o -o %t.wasm -r
; RUN: llvm-readobj -t %t.wasm | FileCheck %s

target datalayout = "e-m:e-p:32:32-i64:64-n32:64-S128"
target triple = "wasm32-unknown-unknown-wasm"

define weak void @f() {
  ret void
}

; CHECK:        Symbol {
; CHECK-NEXT:     Name: f
; CHECK-NEXT:     Type: FUNCTION (0x0)
; CHECK-NEXT:     Flags: 0x1
; CHECK-NEXT:   }
