; RUN: llvm-as -o %t.obj %s
; RUN: lld-link /out:%t.exe %t.obj /entry:main /subsystem:console
; RUN: llvm-readobj -file-headers %t.exe | FileCheck %s

; CHECK: LoadConfigTableRVA: 0x1000
; CHECK: LoadConfigTableSize: 0x70

target datalayout = "e-m:w-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-windows-msvc"

@_load_config_used = constant [28 x i32] [i32 112, i32 0, i32 0, i32 0, i32 0, i32 0, i32 0, i32 0, i32 0, i32 0, i32 0, i32 0, i32 0, i32 0, i32 0, i32 0, i32 0, i32 0, i32 0, i32 0, i32 0, i32 0, i32 0, i32 0, i32 0, i32 0, i32 0, i32 0]

define void @main() {
  ret void
}
