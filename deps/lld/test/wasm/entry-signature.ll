; Verify that the entry point signauture can be flexible.
; RUN: llc -filetype=obj %s -o %t.o
; RUN: wasm-ld -o %t1.wasm %t.o

target triple = "wasm32-unknown-unknown-wasm"

define hidden i32 @_start(i32, i64) local_unnamed_addr #0 {
entry:
  ret i32 0
}
