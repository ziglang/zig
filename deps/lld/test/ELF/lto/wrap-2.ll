; REQUIRES: x86
; LTO
; RUN: llvm-as %s -o %t.o
; RUN: llvm-as %S/Inputs/wrap-bar.ll -o %t1.o
; RUN: ld.lld %t.o %t1.o -shared -o %t.so -wrap=bar
; RUN: llvm-objdump -d %t.so | FileCheck %s
; RUN: llvm-readobj -t %t.so | FileCheck -check-prefix=BIND %s

; ThinLTO
; RUN: opt -module-summary %s -o %t.o
; RUN: opt -module-summary %S/Inputs/wrap-bar.ll -o %t1.o
; RUN: ld.lld %t.o %t1.o -shared -o %t.so -wrap=bar
; RUN: llvm-objdump -d %t.so | FileCheck %s -check-prefix=THIN
; RUN: llvm-readobj -t %t.so | FileCheck -check-prefix=BIND %s

; Make sure that calls in foo() are not eliminated and that bar is
; routed to __wrap_bar and __real_bar is routed to bar.

; CHECK:      foo:
; CHECK-NEXT: pushq	%rax
; CHECK-NEXT: callq{{.*}}<__wrap_bar>
; CHECK-NEXT: callq{{.*}}<bar>

; THIN:      foo:
; THIN-NEXT: pushq	%rax
; THIN-NEXT: callq{{.*}}<__wrap_bar>
; THIN-NEXT: popq  %rax
; THIN-NEXT: jmp{{.*}}<bar>

; Check that bar and __wrap_bar retain their original binding.
; BIND:      Name: bar
; BIND-NEXT: Value:
; BIND-NEXT: Size:
; BIND-NEXT: Binding: Local
; BIND:      Name: __real_bar
; BIND-NEXT: Value:
; BIND-NEXT: Size:
; BIND-NEXT: Binding: Local
; BIND:      Name: __wrap_bar
; BIND-NEXT: Value:
; BIND-NEXT: Size:
; BIND-NEXT: Binding: Local

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

declare void @bar()
declare void @__real_bar()

define void @foo() {
  call void @bar()
  call void @__real_bar()
  ret void
}
