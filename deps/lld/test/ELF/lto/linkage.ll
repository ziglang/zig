; REQUIRES: x86
; RUN: llvm-as %s -o %t1.o
; RUN: ld.lld -m elf_x86_64 %t1.o %t1.o -o %t.so -shared
; RUN: llvm-nm %t.so | FileCheck %s

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

; Should not encounter a duplicate symbol error for @.str
@.str = private unnamed_addr constant [4 x i8] c"Hey\00", align 1

; Should not encounter a duplicate symbol error for @llvm.global_ctors
@llvm.global_ctors = appending global [1 x { i32, void ()*, i8* }] [{ i32, void ()*, i8* } { i32 65535, void ()* @ctor, i8* null }]
define internal void @ctor() {
  ret void
}

; Should not try to merge a declaration into the combined module.
declare i32 @llvm.ctpop.i32(i32)
; CHECK-NOT: llvm.ctpop.i32
