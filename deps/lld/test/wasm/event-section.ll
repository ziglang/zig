; RUN: llc -filetype=obj -exception-model=wasm -mattr=+exception-handling %p/Inputs/event-section1.ll -o %t1.o
; RUN: llc -filetype=obj -exception-model=wasm -mattr=+exception-handling %p/Inputs/event-section2.ll -o %t2.o
; RUN: llc -filetype=obj -exception-model=wasm -mattr=+exception-handling %s -o %t.o
; RUN: wasm-ld -o %t.wasm %t.o %t1.o %t2.o
; RUN: obj2yaml %t.wasm | FileCheck %s

target datalayout = "e-m:e-p:32:32-i64:64-n32:64-S128"
target triple = "wasm32-unknown-unknown"

declare void @foo(i8*)
declare void @bar(i8*)

define void @_start() {
  call void @foo(i8* null)
  call void @bar(i8* null)
  ret void
}

; CHECK:      Sections:
; CHECK-NEXT:   - Type:            TYPE
; CHECK-NEXT:     Signatures:
; CHECK-NEXT:       - Index:           0
; CHECK-NEXT:         ReturnType:      NORESULT
; CHECK-NEXT:         ParamTypes:      []
; CHECK-NEXT:       - Index:           1
; CHECK-NEXT:         ReturnType:      NORESULT
; CHECK-NEXT:         ParamTypes:
; CHECK-NEXT:           - I32

; CHECK:        - Type:            EVENT
; CHECK-NEXT:     Events:
; CHECK-NEXT:       - Index:           0
; CHECK-NEXT:         Attribute:       0
; CHECK-NEXT:         SigIndex:        1
