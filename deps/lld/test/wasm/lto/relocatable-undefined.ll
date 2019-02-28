; RUN: llvm-as %s -o %t.o
; RUN: wasm-ld -r -o %t.wasm %t.o
; RUN: obj2yaml %t.wasm | FileCheck %s

target datalayout = "e-m:e-p:32:32-i64:64-n32:64-S128"
target triple = "wasm32-unknown-unknown"

@missing_data = external global i32
declare i32 @missing_func() local_unnamed_addr

define i32 @foo() {
entry:
  %0 = call i32 @missing_func()
  %1 = load i32, i32* @missing_data, align 4
  ret i32 %1
}


; CHECK:        - Type:            CUSTOM
; CHECK-NEXT:     Name:            linking
; CHECK-NEXT:     Version:         2
; CHECK-NEXT:     SymbolTable:     
; CHECK-NEXT:       - Index:           0
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            missing_func
; CHECK-NEXT:         Flags:           [ UNDEFINED ]
; CHECK-NEXT:         Function:        0
; CHECK-NEXT:       - Index:           1
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            foo
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        1
; CHECK-NEXT:       - Index:           2
; CHECK-NEXT:         Kind:            DATA
; CHECK-NEXT:         Name:            missing_data
; CHECK-NEXT:         Flags:           [ UNDEFINED ]
