; REQUIRES: x86
; RUN: llvm-as -o %t.obj %s
; RUN: mkdir -p %t.dir
; RUN: llvm-mc -triple=x86_64-pc-windows-msvc -filetype=obj -o %t.dir/bitcode.obj %p/Inputs/msvclto.s
; RUN: lld-link %t.obj %t.dir/bitcode.obj /msvclto /out:%t.exe /opt:lldlto=1 /opt:icf \
; RUN:   /entry:main /verbose 2> %t.log || true
; RUN: FileCheck %s < %t.log

; CHECK: /opt:icf /entry:main
; CHECK: /verbose

target datalayout = "e-m:w-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-windows-msvc"

declare void @foo()

define i32 @main() {
  call void @foo()
  ret i32 0
}
