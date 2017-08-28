; REQUIRES: x86
; RUN: llvm-as -o %t.obj %s
; RUN: lld-link /dll /out:%t.dll %t.obj
; RUN: llvm-objdump -d %t.dll | FileCheck %s

; Checks that code for foo is emitted, as required by the /INCLUDE directive.
; CHECK: xorl %eax, %eax
; CHECK-NEXT: retq

target datalayout = "e-m:w-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-windows-msvc"

define void @_DllMainCRTStartup() {
  ret void
}

define i32 @foo() {
  ret i32 0
}

!llvm.linker.options = !{!0}
!0 = !{!"/INCLUDE:foo"}
