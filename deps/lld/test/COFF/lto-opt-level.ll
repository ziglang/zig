; RUN: llvm-as -o %t.obj %s
; RUN: lld-link /out:%t0.exe /entry:main /subsystem:console /opt:lldlto=0 /debug %t.obj
; RUN: llvm-nm %t0.exe | FileCheck --check-prefix=CHECK-O0 %s
; RUN: lld-link /out:%t2.exe /entry:main /subsystem:console /opt:lldlto=2 /debug %t.obj
; RUN: llvm-nm %t2.exe | FileCheck --check-prefix=CHECK-O2 %s
; RUN: lld-link /out:%t2a.exe /entry:main /subsystem:console /debug %t.obj
; RUN: llvm-nm %t2a.exe | FileCheck --check-prefix=CHECK-O2 %s

target datalayout = "e-m:w-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-windows-msvc"

; CHECK-O0: foo
; CHECK-O2-NOT: foo
define internal void @foo() {
  ret void
}

define void @main() {
  call void @foo()
  ret void
}
