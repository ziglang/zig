; RUN: llc -filetype=obj -mtriple=wasm32-unknown-unknown-wasm %s -o %t.o
; RUN: llc -filetype=obj -mtriple=wasm32-unknown-unknown-wasm %S/Inputs/archive1.ll -o %t.a1.o
; RUN: llc -filetype=obj -mtriple=wasm32-unknown-unknown-wasm %S/Inputs/archive2.ll -o %t.a2.o
; RUN: llc -filetype=obj -mtriple=wasm32-unknown-unknown-wasm %S/Inputs/hello.ll -o %t.a3.o
; RUN: llvm-ar rcs %t.a %t.a1.o %t.a2.o %t.a3.o
; RUN: lld -flavor wasm %t.a %t.o -o %t.wasm
; RUN: llvm-nm -a %t.wasm | FileCheck %s

declare i32 @foo() local_unnamed_addr #1

define i32 @_start() local_unnamed_addr #0 {
entry:
  %call = tail call i32 @foo() #2
  ret i32 %call
}

; Verify that multually dependant object files in an archive is handled
; correctly.

; CHECK:      00000002 T _start
; CHECK-NEXT: 00000002 T _start
; CHECK-NEXT: 00000000 T bar
; CHECK-NEXT: 00000000 T bar
; CHECK-NEXT: 00000001 T foo
; CHECK-NEXT: 00000001 T foo

; Verify that symbols from unused objects don't appear in the symbol table
; CHECK-NOT: hello

; Specifying the same archive twice is allowed.
; RUN: lld -flavor wasm %t.a %t.a %t.o -o %t.wasm
