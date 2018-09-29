; REQUIRES: x86
; RUN: llvm-as %s -o %t.o
; RUN: ld.lld %t.o -o %t.so -save-temps -mllvm -debug-pass=Arguments -shared 2>&1 | FileCheck %s --check-prefix=MLLVM
; RUN: llvm-dis %t.so.0.4.opt.bc -o - | FileCheck %s

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

@llvm.global_ctors = appending global [1 x { i32, void ()*, i8* }] [{ i32, void ()*, i8* } { i32 65535, void ()* @ctor, i8* null }]
define void @ctor() {
  ret void
}

; `@ctor` doesn't do anything and so the optimizer should kill it, leaving no ctors
; CHECK: @llvm.global_ctors = appending global [0 x { i32, void ()*, i8* }] zeroinitializer

; MLLVM: Pass Arguments:
