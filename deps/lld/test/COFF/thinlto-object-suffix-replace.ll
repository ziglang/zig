; REQUIRES: x86

; Test to make sure the thinlto-object-suffix-replace option is handled
; correctly.

; Generate bitcode file with summary, as well as a minimized bitcode without
; the debug metadata for the thin link.
; RUN: opt -thinlto-bc %s -thin-link-bitcode-file=%t1.thinlink.bc -o %t1.obj

; First perform the thin link on the normal bitcode file, and save the
; resulting index.
; RUN: lld-link -thinlto-index-only -entry:main %t1.obj -out:%t3.exe
; RUN: cp %t1.obj.thinlto.bc %t1.obj.thinlto.bc.orig

; Next perform the thin link on the minimized bitcode file, and compare dump
; of the resulting index to the above dump to ensure they are identical.
; RUN: rm -f %t1.obj.thinlto.bc
; Make sure it isn't inadvertently using the regular bitcode file.
; RUN: rm -f %t1.obj
; RUN: lld-link -entry:main -thinlto-index-only \
; RUN:     -thinlto-object-suffix-replace:".thinlink.bc;.obj" \
; RUN:     %t1.thinlink.bc -out:%t3.exe
; RUN: diff %t1.obj.thinlto.bc.orig %t1.obj.thinlto.bc

; Ensure lld generates error if suffix replace option not in 'old;new' format.
; RUN: rm -f %t1.obj.thinlto.bc
; RUN: not lld-link -entry:main -thinlto-index-only \
; RUN: -thinlto-object-suffix-replace:"abc:def" %t1.thinlink.bc \
; RUN: -out:%t3.exe 2>&1 | FileCheck %s --check-prefix=ERR1
; ERR1: -thinlto-object-suffix-replace: expects 'old;new' format, but got abc:def

; If filename does not end with old suffix, no suffix change should occur,
; so ".thinlto.bc" will simply be appended to the input file name.
; RUN: rm -f %t1.thinlink.bc.thinlto.bc
; RUN: lld-link -entry:main -thinlto-index-only \
; RUN: -thinlto-object-suffix-replace:".abc;.obj" %t1.thinlink.bc -out:%t3.exe
; RUN: ls %t1.thinlink.bc.thinlto.bc

target datalayout = "e-m:w-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-windows-msvc19.0.24215"

define void @main() {
entry:
  ret void
}

!llvm.dbg.cu = !{}

!1 = !{i32 2, !"Debug Info Version", i32 3}
!llvm.module.flags = !{!1}
