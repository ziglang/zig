; RUN: llc -filetype=obj %s -o %t.o
; RUN: wasm-ld --allow-undefined -o %t.wasm %t.o
; RUN: obj2yaml %t.wasm | FileCheck %s

target triple = "wasm32-unknown-unknown"

declare void @f0() #0

define void @_start() {
    call void @f0()
    ret void
}

attributes #0 = { "wasm-import-module"="somewhere" "wasm-import-name"="something" }

; CHECK:        - Type:            IMPORT
; CHECK-NEXT:     Imports:
; CHECK-NEXT:       - Module:          somewhere
; CHECK-NEXT:         Field:           something
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         SigIndex:        0

; CHECK:        - Type:            CUSTOM
; CHECK-NEXT:     Name:            name
; CHECK-NEXT:     FunctionNames:
; CHECK-NEXT:       - Index:           0
; CHECK-NEXT:         Name:            f0
