; RUN: llc -filetype=obj -mtriple=wasm32-unknown-uknown-wasm %p/Inputs/comdat1.ll -o %t1.o
; RUN: llc -filetype=obj -mtriple=wasm32-unknown-uknown-wasm %p/Inputs/comdat2.ll -o %t2.o
; RUN: llc -filetype=obj -mtriple=wasm32-unknown-uknown-wasm %s -o %t.o
; RUN: wasm-ld --export-dynamic -o %t.wasm %t.o %t1.o %t2.o
; RUN: obj2yaml %t.wasm | FileCheck %s

target triple = "wasm32-unknown-unknown"

declare void @__wasm_call_ctors()
declare i32 @comdatFn()

define void @_start() {
entry:
  call void @__wasm_call_ctors()
  %call = call i32 @comdatFn()
  ret void
}

; CHECK:       - Type:            GLOBAL
; CHECK-NEXT:    Globals:
; CHECK-NEXT:      - Index:           0
; CHECK-NEXT:        Type:            I32
; CHECK-NEXT:        Mutable:         true
; CHECK-NEXT:        InitExpr:
; CHECK-NEXT:          Opcode:          I32_CONST
; CHECK-NEXT:          Value:           66576
; CHECK-NEXT:      - Index:           1
; CHECK-NEXT:        Type:            I32
; CHECK-NEXT:        Mutable:         false
; CHECK-NEXT:        InitExpr:
; CHECK-NEXT:          Opcode:          I32_CONST
; CHECK-NEXT:          Value:           1024
; CHECK-NEXT:  - Type:            EXPORT
; CHECK-NEXT:    Exports:
; CHECK-NEXT:      - Name:            memory
; CHECK-NEXT:        Kind:            MEMORY
; CHECK-NEXT:        Index:           0
; CHECK-NEXT:      - Name:            _start
; CHECK-NEXT:        Kind:            FUNCTION
; CHECK-NEXT:        Index:           1
; CHECK-NEXT:      - Name:            comdatFn
; CHECK-NEXT:        Kind:            FUNCTION
; CHECK-NEXT:        Index:           2
; CHECK-NEXT:      - Name:            constantData
; CHECK-NEXT:        Kind:            GLOBAL
; CHECK-NEXT:        Index:           1
; CHECK-NEXT:      - Name:            callComdatFn1
; CHECK-NEXT:        Kind:            FUNCTION
; CHECK-NEXT:        Index:           4
; CHECK-NEXT:      - Name:            callComdatFn2
; CHECK-NEXT:        Kind:            FUNCTION
; CHECK-NEXT:        Index:           5
; CHECK-NEXT:  - Type:            ELEM
; CHECK-NEXT:    Segments:
; CHECK-NEXT:      - Offset:
; CHECK-NEXT:          Opcode:          I32_CONST
; CHECK-NEXT:          Value:           1
; CHECK-NEXT:        Functions:       [ 2 ]
; CHECK-NEXT:  - Type:            CODE
; CHECK-NEXT:    Functions:
; CHECK-NEXT:      - Index:           0
; CHECK-NEXT:        Locals:
; CHECK-NEXT:        Body:            10030B
; CHECK-NEXT:      - Index:           1
; CHECK-NEXT:        Locals:
; CHECK-NEXT:        Body:            1080808080001082808080001A0B
; CHECK-NEXT:      - Index:           2
; CHECK-NEXT:        Locals:
; CHECK-NEXT:        Body:            4180888080000B
; CHECK-NEXT:      - Index:           3
; CHECK-NEXT:        Locals:
; CHECK-NEXT:        Body:            0B
; CHECK-NEXT:      - Index:           4
; CHECK-NEXT:        Locals:
; CHECK-NEXT:        Body:            4181808080000B
; CHECK-NEXT:      - Index:           5
; CHECK-NEXT:        Locals:
; CHECK-NEXT:        Body:            4181808080000B
; CHECK-NEXT:  - Type:            DATA
; CHECK-NEXT:    Segments:
; CHECK-NEXT:      - SectionOffset:   7
; CHECK-NEXT:        InitFlags:       0
; CHECK-NEXT:        Offset:
; CHECK-NEXT:          Opcode:          I32_CONST
; CHECK-NEXT:          Value:           1024
; CHECK-NEXT:        Content:         '616263'
