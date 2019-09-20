; RUN: llvm-as %s -o %t.o
; RUN: wasm-ld %t.o -o %t.wasm
; RUN: obj2yaml %t.wasm | FileCheck %s

; Test that undefined weak external functions are handled in the LTO case
; We had a bug where stub function generation was failing because functions
; that are in bitcode (pre-LTO) don't have signatures assigned.

target datalayout = "e-m:e-p:32:32-i64:64-n32:64-S128"
target triple = "wasm32-unknown-unknown"

declare extern_weak i32 @foo()

define void @_start() #0 {
entry:
    %call2 = call i32 @foo()
    ret void
}

; CHECK: Name:            'undefined:foo'
