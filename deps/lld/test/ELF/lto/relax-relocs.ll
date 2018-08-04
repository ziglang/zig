; REQUIRES: x86
; RUN: llvm-as %s -o %t.o
; RUN: ld.lld -save-temps -shared %t.o -o %t.so
; RUN: llvm-readobj -r %t.so.lto.o | FileCheck %s

; Test that we produce R_X86_64_REX_GOTPCRELX instead of R_X86_64_GOTPCREL
; CHECK: R_X86_64_REX_GOTPCRELX foo

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

@foo = external global i32
define i32 @bar() {
  %t = load i32, i32* @foo
  ret i32 %t
}
