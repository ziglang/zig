; RUN: llvm-as %s -o %t.o
; RUN: wasm-ld %t.o -o %t.wasm -lto-O0

; Atomic operations will not fail to compile if atomics are not
; enabled because LLVM atomics will be lowered to regular ops.

target datalayout = "e-m:e-p:32:32-i64:64-n32:64-S128"
target triple = "wasm32-unknown-unknown-wasm"

@foo = hidden global i32 1

define void @_start() {
  %1 = load atomic i32, i32* @foo unordered, align 4
  ret void
}
