; REQUIRES: x86
; RUN: llvm-as %s -o %t.o
; RUN: ld.lld %t.o %t.o -o %t.so -save-temps -shared
; RUN: llvm-dis %t.so.0.2.internalize.bc -o - | FileCheck %s

target triple = "x86_64-unknown-linux-gnu"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"

$foo = comdat any
@foo = linkonce_odr unnamed_addr constant i32 42, comdat

; CHECK: @foo = internal unnamed_addr constant i32 42, comdat
