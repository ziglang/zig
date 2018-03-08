; RUN: llvm-as -o %t.obj %s
; RUN: lld-link /out:%t0.exe /entry:main /subsystem:console /opt:lldlto=0 /lldmap:%t0.map %t.obj
; RUN: FileCheck --check-prefix=CHECK-O0 %s < %t0.map
; RUN: lld-link /out:%t2.exe /entry:main /subsystem:console /opt:lldlto=2 /lldmap:%t2.map %t.obj
; RUN: FileCheck --check-prefix=CHECK-O2 %s < %t2.map
; RUN: lld-link /out:%t2a.exe /entry:main /subsystem:console /lldmap:%t2a.map %t.obj
; RUN: FileCheck --check-prefix=CHECK-O2 %s < %t2a.map

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
