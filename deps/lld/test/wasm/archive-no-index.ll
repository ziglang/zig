; Tests error on archive file without a symbol table
; RUN: llvm-as -o %t.o %s
; RUN: llvm-as -o %t.archive.o %S/Inputs/archive1.ll
; RUN: rm -f %t.a
; RUN: llvm-ar crS %t.a %t.archive.o

; RUN: not wasm-ld -o out.wasm %t.o %t.a 2>&1 | FileCheck %s

define i32 @_start() {
  ret i32 0
}

; CHECK: archive has no index; run ranlib to add one
