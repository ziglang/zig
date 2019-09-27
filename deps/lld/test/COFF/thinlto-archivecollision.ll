; REQUIRES: x86
; RUN: rm -fr %t
; RUN: mkdir %t %t/a %t/b
; RUN: opt -thinlto-bc -o %t/main.obj %s
; RUN: opt -thinlto-bc -o %t/a/bar.obj %S/Inputs/lto-dep.ll
; RUN: opt -thinlto-bc -o %t/b/bar.obj %S/Inputs/bar.ll
; RUN: llvm-ar crs %t/libbar.lib %t/a/bar.obj %t/b/bar.obj
; RUN: lld-link -out:%t/main.exe -entry:main -lldsavetemps \
; RUN:     -subsystem:console %t/main.obj %t/libbar.lib
; RUN: FileCheck %s < %t/main.exe.resolution.txt

; CHECK: {{/|\\\\thinlto-archivecollision.ll.tmp/main.obj$}}
; CHECK: {{^-r=.*/|\\\\thinlto-archivecollision.ll.tmp/main.obj,main,px$}}
; CHECK: {{/|\\\\thinlto-archivecollision.ll.tmp/libbar.libbar.obj[0-9]+$}}
; CHECK-NEXT: {{^-r=.*/|\\\\thinlto-archivecollision.ll.tmp/libbar.libbar.obj[0-9]+,foo,p$}}
; CHECK-NEXT: {{/|\\\\thinlto-archivecollision.ll.tmp/libbar.libbar.obj[0-9]+$}}
; CHECK-NEXT: {{^-r=.*/|\\\\thinlto-archivecollision.ll.tmp/libbar.libbar.obj[0-9]+,bar,p$}}

target datalayout = "e-m:w-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-windows-msvc"

declare void @bar()
declare void @foo()

define i32 @main() {
  call void @foo()
  call void @bar()
  ret i32 0
}
