; RUN: llc -filetype=obj %p/Inputs/ret32.ll -o %t.ret32.o
; RUN: llc -filetype=obj %s -o %t.main.o
; RUN: wasm-ld --fatal-warnings -o %t.wasm %t.ret32.o %t.main.o
; RUN: wasm-ld --fatal-warnings -o %t.wasm %t.main.o %t.ret32.o

target triple = "wasm32-unknown-unknown"

; Function declartion with incorrect signature.
declare dso_local void @ret32()

; Simply taking the address of the function should *not* generate the
; the signature mismatch warning.
@ptr = dso_local global i8* bitcast (void ()* @ret32 to i8*), align 8

define hidden void @_start() local_unnamed_addr {
  %addr = load i32 ()*, i32 ()** bitcast (i8** @ptr to i32 ()**), align 8
  call i32 %addr()
  ret void
}
