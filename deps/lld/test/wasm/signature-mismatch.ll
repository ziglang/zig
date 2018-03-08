; RUN: llc -filetype=obj -mtriple=wasm32-unknown-unknown-wasm %p/Inputs/ret32.ll -o %t.ret32.o
; RUN: llc -filetype=obj -mtriple=wasm32-unknown-unknown-wasm %s -o %t.main.o
; RUN: not lld -flavor wasm --check-signatures -o %t.wasm %t.main.o %t.ret32.o 2>&1 | FileCheck %s

; Function Attrs: nounwind
define hidden void @_start() local_unnamed_addr #0 {
entry:
  %call = tail call i32 @ret32(i32 1, i64 2, i32 3) #2
  ret void
}

declare i32 @ret32(i32, i64, i32) local_unnamed_addr #1

; CHECK: error: function signature mismatch: ret32
; CHECK-NEXT: >>> defined as (I32, I64, I32) -> I32 in {{.*}}.main.o
; CHECK-NEXT: >>> defined as (F32) -> I32 in {{.*}}.ret32.o
