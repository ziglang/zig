; REQUIRES: x86
; RUN: rm -fr %T/thinlto-archives
; RUN: mkdir %T/thinlto-archives %T/thinlto-archives/a %T/thinlto-archives/b
; RUN: opt -thinlto-bc -o %T/thinlto-archives/main.obj %s
; RUN: opt -thinlto-bc -o %T/thinlto-archives/a/bar.obj %S/Inputs/lto-dep.ll
; RUN: opt -thinlto-bc -o %T/thinlto-archives/b/bar.obj %S/Inputs/bar.ll
; RUN: llvm-ar crs %T/thinlto-archives/a.lib %T/thinlto-archives/a/bar.obj
; RUN: llvm-ar crs %T/thinlto-archives/b.lib %T/thinlto-archives/b/bar.obj
; RUN: lld-link /out:%T/thinlto-archives/main.exe -entry:main \
; RUN:     -subsystem:console %T/thinlto-archives/main.obj \
; RUN:     %T/thinlto-archives/a.lib %T/thinlto-archives/b.lib

target datalayout = "e-m:w-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-windows-msvc"

declare void @bar()
declare void @foo()

define i32 @main() {
  call void @foo()
  call void @bar()
  ret i32 0
}
