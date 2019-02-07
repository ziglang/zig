; REQUIRES: x86
; RUN: rm -f %t.a
; RUN: llvm-as -o %t.o %s
; RUN: llvm-as -o %t2.o %S/Inputs/libcall-archive.ll
; RUN: llvm-mc -filetype=obj -triple=x86_64-unknown-linux -o %t3.o %S/Inputs/libcall-archive.s
; RUN: llvm-ar rcs %t.a %t2.o %t3.o
; RUN: ld.lld -o %t %t.o %t.a
; RUN: llvm-nm %t | FileCheck %s
; RUN: ld.lld -o %t2 %t.o --start-lib %t2.o %t3.o --end-lib
; RUN: llvm-nm %t2 | FileCheck %s

; CHECK-NOT: T __sync_val_compare_and_swap_8
; CHECK: T _start
; CHECK: T memcpy

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

define void @_start(i8* %a, i8* %b) {
entry:
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %a, i8* %b, i64 1024, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8* nocapture, i8* nocapture, i64, i1)
