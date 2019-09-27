; RUN: llc -filetype=obj %s -o %t.o
; RUN: llc -filetype=obj %S/Inputs/ret32.ll -o %t.a1.o
; RUN: rm -f %t.a
; RUN: llvm-ar rcs %t.a %t.a1.o
; RUN: wasm-ld %t.o %t.a -o %t.wasm
; RUN: obj2yaml %t.wasm | FileCheck %s

target triple = "wasm32-unknown-unknown"

declare extern_weak i32 @ret32()

define void @_start() {
entry:
  %call1 = call i32 @ret32()
  ret void
}

; CHECK: Name: 'undefined:ret32'
; CHECK-NOT: Name: ret32
