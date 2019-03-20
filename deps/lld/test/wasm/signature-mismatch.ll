; RUN: llc -filetype=obj %p/Inputs/ret32.ll -o %t.ret32.o
; RUN: llc -filetype=obj %s -o %t.main.o
; RUN: not wasm-ld --fatal-warnings -o %t.wasm %t.main.o %t.ret32.o 2>&1 | FileCheck %s
; Run the test again by with the object files in the other order to verify
; the check works when the undefined symbol is resolved by an existing defined
; one.
; RUN: not wasm-ld --fatal-warnings -o %t.wasm %t.ret32.o %t.main.o 2>&1 | FileCheck %s -check-prefix=REVERSE

target triple = "wasm32-unknown-unknown"

; Function Attrs: nounwind
define hidden void @_start() local_unnamed_addr #0 {
entry:
  %call = tail call i32 @ret32(i32 1, i64 2, i32 3) #2
  ret void
}

declare i32 @ret32(i32, i64, i32) local_unnamed_addr #1

; CHECK: error: function signature mismatch: ret32
; CHECK-NEXT: >>> defined as (i32, i64, i32) -> i32 in {{.*}}.main.o
; CHECK-NEXT: >>> defined as (f32) -> i32 in {{.*}}.ret32.o

; REVERSE: error: function signature mismatch: ret32
; REVERSE-NEXT: >>> defined as (f32) -> i32 in {{.*}}.ret32.o
; REVERSE-NEXT: >>> defined as (i32, i64, i32) -> i32 in {{.*}}.main.o
