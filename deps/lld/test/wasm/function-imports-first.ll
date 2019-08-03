; RUN: llc -filetype=obj %p/Inputs/ret32.ll -o %t.ret32.o
; RUN: llc -filetype=obj %s -o %t.o
; RUN: wasm-ld -o %t.wasm %t.o %t.ret32.o
; RUN: obj2yaml %t.wasm | FileCheck %s

target triple = "wasm32-unknown-unknown"

; Function Attrs: nounwind
define hidden void @_start() local_unnamed_addr #0 {
entry:
  %call = tail call i32 @ret32(float 0.000000e+00) #2
  ret void
}

declare i32 @ret32(float) local_unnamed_addr #1

; CHECK:  - Type:            TYPE
; CHECK:    Signatures:
; CHECK-NEXT:      - Index:           0
; CHECK-NEXT:        ReturnType:      NORESULT
; CHECK-NEXT:        ParamTypes:
; CHECK-NEXT:      - Index:           1
; CHECK-NEXT:        ReturnType:      I32
; CHECK-NEXT:        ParamTypes:
; CHECK-NEXT:          - F32
; CHECK:  - Type:            FUNCTION
; CHECK-NEXT:    FunctionTypes: [ 0, 1 ]
; CHECK:  - Type:            CODE
; CHECK-NEXT:    Functions:
; CHECK-NEXT:      - Index:           0
; CHECK-NEXT:        Locals:
; CHECK-NEXT:        Body:            43000000001081808080001A0B
; CHECK-NEXT:      - Index:           1
; CHECK-NEXT:        Locals:
; CHECK-NEXT:        Body:            41000B
; CHECK-NEXT:   - Type:            CUSTOM
; CHECK-NEXT:     Name:            name
; CHECK-NEXT:     FunctionNames:
; CHECK-NEXT:       - Index:           0
; CHECK-NEXT:         Name:            _start
; CHECK-NEXT:       - Index:           1
; CHECK-NEXT:         Name:            ret32
; CHECK-NEXT: ...
