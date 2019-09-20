; RUN: llc -filetype=obj -o %t.o %s
; RUN: wasm-ld %t.o -o %t.wasm
; RUN: obj2yaml %t.wasm | FileCheck %s

; RUN: wasm-ld %t.o -o %t.wasm
; RUN: obj2yaml %t.wasm | FileCheck %s

; RUN: wasm-ld --export=__wasm_call_ctors %t.o -o %t.export.wasm
; RUN: obj2yaml %t.export.wasm | FileCheck %s -check-prefix=EXPORT

; Test that the __wasm_call_ctor function if not referenced

target triple = "wasm32-unknown-unknown"

define hidden void @_start() {
entry:
  ret void
}

define hidden void @func1() {
entry:
  ret void
}

define hidden void @func2() {
entry:
  ret void
}

define i32 @__cxa_atexit(i32 %func, i32 %arg, i32 %dso_handle) {
  ret i32 0
}

@llvm.global_ctors = appending global [1 x { i32, void ()*, i8* }] [
  { i32, void ()*, i8* } { i32 1, void ()* @func1, i8* null }
]

@llvm.global_dtors = appending global [1 x { i32, void ()*, i8* }] [
  { i32, void ()*, i8* } { i32 1, void ()* @func2, i8* null }
]

; CHECK-NOT: __cxa_atexit
; CHECK-NOT: __wasm_call_ctors

; EXPORT: __wasm_call_ctors
; EXPORT: func1
; EXPORT: func2
; EXPORT: __cxa_atexit
