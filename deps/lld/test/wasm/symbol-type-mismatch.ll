; RUN: llc -filetype=obj %s -o %t.o
; RUN: llc -filetype=obj %p/Inputs/ret32.ll -o %t.ret32.o
; RUN: not wasm-ld -o %t.wasm %t.o %t.ret32.o 2>&1 | FileCheck %s

target triple = "wasm32-unknown-unknown"

@ret32 = extern_weak global i32, align 4

; CHECK: error: symbol type mismatch: ret32
; CHECK: >>> defined as WASM_SYMBOL_TYPE_DATA in {{.*}}symbol-type-mismatch.ll.tmp.o
; CHECK: >>> defined as WASM_SYMBOL_TYPE_FUNCTION in {{.*}}.ret32.o
