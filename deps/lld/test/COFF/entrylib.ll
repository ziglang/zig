; REQUIRES: x86
; RUN: llvm-as -o %t.obj %s
; RUN: rm -f %t.lib
; RUN: llvm-ar cru %t.lib %t.obj
; RUN: lld-link /out:%t.exe /entry:main %t.lib

target datalayout = "e-m:w-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-windows-msvc"

define i32 @main() {
  ret i32 0
}
