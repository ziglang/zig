; RUN: llc -filetype=obj %s -o %t.o
; RUN: llc -filetype=obj %p/Inputs/ret32.ll -o %t.ret32.o
; RUN: wasm-ld --emit-relocs -o %t.wasm %t.o %t.ret32.o
; RUN: obj2yaml %t.wasm | FileCheck %s

target triple = "wasm32-unknown-unknown"

declare i32 @ret32(float)

define void @unused_function() {
  ret void
}

define hidden void @_start() local_unnamed_addr #0 {
entry:
  call i32 @ret32(float 0.0)
  ret void
}

; CHECK:        - Type:            CODE
; CHECK-NEXT:     Relocations:
; CHECK-NEXT:       - Type:            R_WASM_FUNCTION_INDEX_LEB
; CHECK-NEXT:         Index:           1
; CHECK-NEXT:         Offset:          0x00000009

; CHECK:        - Type:            CUSTOM
; CHECK-NEXT:     Name:            linking
; CHECK-NEXT:     Version:         2
; CHECK-NEXT:     SymbolTable:
; CHECK-NEXT:       - Index:           0
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            _start
; CHECK-NEXT:         Flags:           [  ]
; CHECK-NEXT:         Function:        0
; CHECK-NEXT:       - Index:           1
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Name:            ret32
; CHECK-NEXT:         Flags:           [ VISIBILITY_HIDDEN ]
; CHECK-NEXT:         Function:        1
