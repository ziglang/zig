; RUN: llc -filetype=obj %s -o %t1.o
; RUN: llc -filetype=obj  %S/Inputs/custom.ll -o %t2.o
; RUN: wasm-ld --relocatable -o %t.wasm %t1.o %t2.o
; RUN: obj2yaml %t.wasm | FileCheck %s

target triple = "wasm32-unknown-unknown"

define i32 @_start() local_unnamed_addr {
entry:
  %retval = alloca i32, align 4
  ret i32 0
}

!0 = !{ !"red", !"extra" }
!wasm.custom_sections = !{ !0 }

; CHECK:        - Type:            CUSTOM
; CHECK-NEXT:     Name:            green
; CHECK-NEXT:     Payload:         '626172717578'
; CHECK-NEXT:   - Type:            CUSTOM
; CHECK-NEXT:     Name:            red
; CHECK-NEXT:     Payload:         6578747261666F6F
