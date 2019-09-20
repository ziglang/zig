; RUN: llvm-as -o %t.bc %s
; RUN: not wasm-ld --export=missing -o %t.wasm %t.bc 2>&1 | FileCheck -check-prefix=CHECK-ERROR %s
; RUN: wasm-ld --export=hidden_function -o %t.wasm %t.bc
; RUN: obj2yaml %t.wasm | FileCheck %s

target datalayout = "e-m:e-p:32:32-i64:64-n32:64-S128"
target triple = "wasm32-unknown-unknown"

define hidden i32 @hidden_function() local_unnamed_addr {
entry:
  ret i32 0
}

define void @_start() local_unnamed_addr {
entry:
  ret void
}

; CHECK-ERROR: error: symbol exported via --export not found: missing

; CHECK:        - Type:            EXPORT
; CHECK-NEXT:     Exports:
; CHECK-NEXT:       - Name:            memory
; CHECK-NEXT:         Kind:            MEMORY
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:       - Name:            hidden_function
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Index:           0
; CHECK-NEXT:       - Name:            _start
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:   - Type:            CODE
