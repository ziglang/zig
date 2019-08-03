; RUN: llc -filetype=obj %p/Inputs/ret32.ll -o %t.ret32.o
; RUN: llc -filetype=obj -o %t.start.o %s
; RUN: wasm-ld -o %t.wasm %t.start.o %t.ret32.o -y ret32 -y _start | FileCheck %s -check-prefix=BOTH
; RUN: wasm-ld -o %t.wasm %t.ret32.o %t.start.o -y ret32 -y _start | FileCheck %s -check-prefix=REVERSED

; check alias
; RUN: wasm-ld -o %t.wasm %t.start.o %t.ret32.o -trace-symbol=_start | FileCheck %s -check-prefixes=JUST-START

target triple = "wasm32-unknown-unknown"

declare i32 @ret32(float %arg)

define void @_start() {
entry:
  %call1 = call i32 @ret32(float 0.0)
  ret void
}

; BOTH:          start.o: definition of _start
; BOTH-NEXT:     start.o: reference to ret32
; BOTH-NEXT:     ret32.o: definition of ret32

; REVERSED:      ret32.o: definition of ret32
; REVERSED-NEXT: start.o: definition of _start
; REVERSED-NEXT: start.o: reference to ret32

; JUST-START: start.o: definition of _start
; JUST-START-NOT: ret32
