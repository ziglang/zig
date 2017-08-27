; REQUIRES: x86
; RUN: llvm-as %s -o %t1.o
; RUN: ld.lld -m elf_x86_64 %t1.o %t1.o -o %t.so -shared

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

define weak void @foo(i32* %p) {
  store i32 5, i32* %p, align 4, !tbaa !0
  ret void
}

!0 = !{!1, !1, i64 0}
!1 = !{!"int", !2}
!2 = !{!"Simple C/C++ TBAA"}
