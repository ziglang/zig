; REQUIRES: x86
; RUN: rm -fr %T/thinlto
; RUN: mkdir %T/thinlto
; RUN: opt -thinlto-bc -o %T/thinlto/main.obj %s
; RUN: opt -thinlto-bc -o %T/thinlto/foo.obj %S/Inputs/lto-dep.ll
; RUN: lld-link /lldsavetemps /out:%T/thinlto/main.exe /entry:main /subsystem:console %T/thinlto/main.obj %T/thinlto/foo.obj
; RUN: llvm-nm %T/thinlto/main.exe1.lto.obj | FileCheck %s

; CHECK-NOT: U foo

target datalayout = "e-m:w-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-windows-msvc"

define i32 @main() {
  call void @foo()
  ret i32 0
}

declare void @foo()
