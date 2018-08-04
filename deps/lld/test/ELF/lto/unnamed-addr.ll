; REQUIRES: x86
; RUN: llvm-as %s -o %t.o
; RUN: ld.lld %t.o -o %t.so -save-temps -shared
; RUN: llvm-dis %t.so.0.4.opt.bc -o - | FileCheck %s

target triple = "x86_64-unknown-linux-gnu"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"

@a = internal unnamed_addr constant i8 42

define i8* @f() {
  ret i8* @a
}

; CHECK: @a = internal unnamed_addr constant i8 42
