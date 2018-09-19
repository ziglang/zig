; REQUIRES: x86
; RUN: llvm-as -o %t.obj %s
; RUN: lld-link /out:%t.exe /entry:foo /subsystem:console %t.obj

target datalayout = "e-m:w-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-windows-msvc"

define void @foo(<4 x i32>* %p, <4 x float>* %q, i1 %t) nounwind {
entry:
  br label %loop
loop:
  store <4 x i32><i32 1073741824, i32 1073741824, i32 1073741824, i32 1073741824>, <4 x i32>* %p
  store <4 x float><float 2.0, float 2.0, float 2.0, float 2.0>, <4 x float>* %q
  br i1 %t, label %loop, label %ret
ret:
  ret void
}
