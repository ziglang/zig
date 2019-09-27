; RUN: llc -filetype=obj %s -o %t.main.o
; RUN: llc -filetype=obj %p/Inputs/ret32.ll -o %t.ret32.o
; RUN: wasm-ld -o %t.wasm %t.main.o %t.ret32.o 2>&1 | FileCheck %s -check-prefix=CHECK-WARN
; RUN: not wasm-ld --fatal-warnings -o %t.wasm %t.main.o %t.ret32.o 2>&1 | FileCheck %s -check-prefix=CHECK-FATAL

; CHECK-WARN: warning: function signature mismatch: ret32
; CHECK-FATAL: error: function signature mismatch: ret32

target triple = "wasm32-unknown-unknown"

define hidden void @_start() local_unnamed_addr #0 {
entry:
  %call = tail call i32 @ret32(i32 1, i64 2, i32 3) #2
  ret void
}

declare i32 @ret32(i32, i64, i32) local_unnamed_addr #1
