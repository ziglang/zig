; REQUIRES: x86
; RUN: rm -fr %T/thinlto-archives
; RUN: mkdir %T/thinlto-archives %T/thinlto-archives/a %T/thinlto-archives/b
; RUN: opt -thinlto-bc -o %T/thinlto-archives/main.obj %s
; RUN: opt -thinlto-bc -o %T/thinlto-archives/a/bar.obj %S/Inputs/lto-dep.ll
; RUN: opt -thinlto-bc -o %T/thinlto-archives/b/bar.obj %S/Inputs/bar.ll
; RUN: llvm-ar crs %T/thinlto-archives/a.lib %T/thinlto-archives/a/bar.obj
; RUN: llvm-ar crs %T/thinlto-archives/b.lib %T/thinlto-archives/b/bar.obj
; RUN: lld-link -out:%T/thinlto-archives/main.exe -entry:main \
; RUN:     -lldsavetemps -subsystem:console %T/thinlto-archives/main.obj \
; RUN:     %T/thinlto-archives/a.lib %T/thinlto-archives/b.lib
; RUN: FileCheck %s < %T/thinlto-archives/main.exe.resolution.txt

; CHECK: {{/thinlto-archives/main.obj$}}
; CHECK: {{^-r=.*/thinlto-archives/main.obj,main,px$}}
; CHECK: {{/thinlto-archives/a.libbar.obj[0-9]+$}}
; CHECK-NEXT: {{^-r=.*/thinlto-archives/a.libbar.obj[0-9]+,foo,p$}}
; CHECK-NEXT: {{/thinlto-archives/b.libbar.obj[0-9]+$}}
; CHECK-NEXT: {{^-r=.*/thinlto-archives/b.libbar.obj[0-9]+,bar,p$}}

target datalayout = "e-m:w-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-windows-msvc"

declare void @bar()
declare void @foo()

define i32 @main() {
  call void @foo()
  call void @bar()
  ret i32 0
}
