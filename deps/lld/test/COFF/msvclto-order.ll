; REQUIRES: x86
; RUN: opt -thinlto-bc %s -o %t.obj
; RUN: llc -filetype=obj %S/Inputs/msvclto-order-a.ll -o %T/msvclto-order-a.obj
; RUN: llvm-ar crs %T/msvclto-order-a.lib %T/msvclto-order-a.obj
; RUN: llc -filetype=obj %S/Inputs/msvclto-order-b.ll -o %T/msvclto-order-b.obj
; RUN: llvm-ar crs %T/msvclto-order-b.lib %T/msvclto-order-b.obj
; RUN: lld-link /verbose /msvclto /out:%t.exe /entry:main %t.obj \
; RUN:     %T/msvclto-order-a.lib %T/msvclto-order-b.lib 2> %t.log || true
; RUN: FileCheck %s < %t.log

; CHECK: : link.exe
; CHECK-NOT: .lib{{$}}
; CHECK: lld-msvclto-order-a{{.*}}.obj
; CHECK-NOT: lld-msvclto-order-b{{.*}}.obj
; CHECK: .lib{{$}}

target datalayout = "e-m:w-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-windows-msvc"

declare void @foo()

define i32 @main() {
  call void @foo()
  ret i32 0
}
