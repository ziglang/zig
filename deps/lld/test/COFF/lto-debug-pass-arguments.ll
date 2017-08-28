; REQUIRES: x86
; RUN: llvm-as %s -o %t.obj
; RUN: lld-link /dll /out:%t.dll %t.obj /mllvm:-debug-pass=Arguments 2>&1 | FileCheck %s

target datalayout = "e-m:w-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-windows-msvc"

define void @dummy() {
  ret void
}

define void @_DllMainCRTStartup() {
  ret void
}

; CHECK: Pass Arguments:
