; REQUIRES: x86
; RUN: rm -f %t.a
; RUN: llvm-as -o %t.obj %s
; RUN: llvm-as -o %t2.obj %S/Inputs/libcall-archive.ll
; RUN: llvm-mc -filetype=obj -triple=i686-unknown-windows -o %t3.obj %S/Inputs/libcall-archive.s
; RUN: llvm-ar rcs %t.a %t2.obj %t3.obj
; RUN: lld-link -out:%t.exe -subsystem:console -entry:start -safeseh:no -lldmap:- %t.obj %t.a | FileCheck %s

; CHECK-NOT: ___sync_val_compare_and_swap_8
; CHECK: _start
; CHECK: _memcpy

target datalayout = "e-m:x-p:32:32-i64:64-f80:32-n8:16:32-a:0:32-S32"
target triple = "i686-unknown-windows"

define void @start(i8* %a, i8* %b) {
entry:
  call void @llvm.memcpy.p0i8.p0i8.i64(i8* %a, i8* %b, i64 1024, i1 false)
  ret void
}

declare void @llvm.memcpy.p0i8.p0i8.i64(i8* nocapture, i8* nocapture, i64, i1)
