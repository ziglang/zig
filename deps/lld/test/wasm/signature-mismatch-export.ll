; RUN: llc -filetype=obj %p/Inputs/ret32.ll -o %t.ret32.o
; RUN: llc -filetype=obj %s -o %t.main.o
; RUN: wasm-ld --export=ret32 -o %t.wasm %t.main.o %t.ret32.o
; RUN: obj2yaml %t.wasm | FileCheck %s

target triple = "wasm32-unknown-unknown"

declare i32 @ret32(i32)

define void @_start() {
entry:
  %call1 = call i32 @ret32(i32 0)
  ret void
}

; CHECK:        - Type:            EXPORT
; CHECK:            - Name:            ret32
; CHECK-NEXT:         Kind:            FUNCTION
; CHECK-NEXT:         Index:           2

; CHECK:        - Type:            CUSTOM
; CHECK-NEXT:     Name:            name
; CHECK-NEXT:     FunctionNames:
; CHECK-NEXT:       - Index:           0
; CHECK-NEXT:         Name:            'unreachable:ret32'
; CHECK-NEXT:       - Index:           1
; CHECK-NEXT:         Name:            _start
; CHECK-NEXT:       - Index:           2
; CHECK-NEXT:         Name:            ret32
; CHECK-NEXT: ...
