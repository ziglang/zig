; RUN: llc -filetype=obj -o %t.o %s
; RUN: llvm-as %S/Inputs/archive.ll -o %t1.o
; RUN: not wasm-ld --fatal-warnings %t.o %t1.o -o %t.wasm 2>&1 | FileCheck %s

; Test that functions defined in bitcode correctly report signature
; mistmaches with existing undefined sybmols in normal objects.

target triple = "wasm32-unknown-unknown"

; f is defined to take no argument in archive.ll which is compiled to bitcode
declare void @f(i32);

define void @_start() {
  call void @f(i32 0)
  ret void
}

; CHECK: >>> defined as (i32) -> void in {{.*}}signature-mismatch.ll.tmp1.o
; CHECK: >>> defined as () -> void in lto.tmp
