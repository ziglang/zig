; REQUIRES: x86
; RUN: rm -fr %T/savetemps
; RUN: mkdir %T/savetemps
; RUN: llvm-as -o %T/savetemps/savetemps.obj %s
; RUN: lld-link /out:%T/savetemps/savetemps.exe /entry:main \
; RUN:     /subsystem:console %T/savetemps/savetemps.obj
; RUN: not llvm-dis -o - %T/savetemps/savetemps.exe.0.0.preopt.bc
; RUN: not llvm-dis -o - %T/savetemps/savetemps.exe.0.2.internalize.bc
; RUN: not llvm-dis -o - %T/savetemps/savetemps.exe.0.4.opt.bc
; RUN: not llvm-dis -o - %T/savetemps/savetemps.exe.0.5.precodegen.bc
; RUN: not llvm-objdump -s %T/savetemps/savetemps.exe.lto.obj
; RUN: lld-link /lldsavetemps /out:%T/savetemps/savetemps.exe /entry:main \
; RUN:     /subsystem:console %T/savetemps/savetemps.obj
; RUN: llvm-dis -o - %T/savetemps/savetemps.exe.0.0.preopt.bc | FileCheck %s
; RUN: llvm-dis -o - %T/savetemps/savetemps.exe.0.2.internalize.bc | FileCheck %s
; RUN: llvm-dis -o - %T/savetemps/savetemps.exe.0.4.opt.bc | FileCheck %s
; RUN: llvm-dis -o - %T/savetemps/savetemps.exe.0.5.precodegen.bc | FileCheck %s
; RUN: llvm-objdump -s %T/savetemps/savetemps.exe.lto.obj | \
; RUN:     FileCheck --check-prefix=CHECK-OBJDUMP %s

; CHECK: define i32 @main()
; CHECK-OBJDUMP: file format COFF

target datalayout = "e-m:w-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-windows-msvc"

define i32 @main() {
  ret i32 0
}
