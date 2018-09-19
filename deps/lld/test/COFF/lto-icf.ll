; REQUIRES: x86
; Test that ICF works after LTO, i.e. both functions have the same address.
; Previously, when we didn't enable function sections, ICF didn't work.

; RUN: llvm-as %s -o %t.bc
; RUN: lld-link -opt:icf -dll -noentry %t.bc -out:%t.dll
; RUN: llvm-readobj -coff-exports %t.dll | FileCheck %s

; CHECK: Export {
; CHECK: Export {
; CHECK:   RVA: 0x[[RVA:.*]]
; CHECK: Export {
; CHECK:   RVA: 0x[[RVA]]
; CHECK-NOT: Export

target datalayout = "e-m:w-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-windows-msvc19.12.25835"

define dllexport i8* @icf_ptr() {
entry:
  ret i8* null
}

define dllexport i64 @icf_int() {
entry:
  ret i64 0
}
