; RUN: llc -filetype=obj %s -o %t.o
; RUN: wasm-ld -wrap nosuchsym -wrap foo -o %t.wasm %t.o
; RUN: wasm-ld -emit-relocs -wrap foo -o %t.wasm %t.o
; RUN: obj2yaml %t.wasm | FileCheck %s

target triple = "wasm32-unknown-unknown"

define i32 @foo() {
  ret i32 1
}

define void @_start() {
entry:
  call i32 @foo()
  ret void
}

declare i32 @__real_foo()

define i32 @__wrap_foo() {
  %rtn = call i32 @__real_foo()
  ret i32 %rtn
}

; CHECK:      - Type:            CODE
; CHECK-NEXT:   Relocations:     
; CHECK-NEXT:     - Type:            R_WASM_FUNCTION_INDEX_LEB
; CHECK-NEXT:       Index:           2
; CHECK-NEXT:       Offset:          0x00000009
; CHECK-NEXT:     - Type:            R_WASM_FUNCTION_INDEX_LEB
; CHECK-NEXT:       Index:           0
; CHECK-NEXT:       Offset:          0x00000013

; CHECK:        FunctionNames:
; CHECK-NEXT:      - Index:           0
; CHECK-NEXT:        Name:            foo
; CHECK-NEXT:      - Index:           1
; CHECK-NEXT:        Name:            _start
; CHECK-NEXT:      - Index:           2
; CHECK-NEXT:        Name:            __wrap_foo
