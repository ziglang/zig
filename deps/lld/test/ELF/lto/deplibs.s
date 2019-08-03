; REQUIRES: x86

; RUN: llvm-as %s -o %t.o
; RUN: not ld.lld -shared %t.o -o /dev/null 2>&1 | FileCheck %s -DOBJ=%t.o

; CHECK: error: [[OBJ]]: unable to find library from dependent library specifier: foo
; CHECK: error: [[OBJ]]: unable to find library from dependent library specifier: bar

target triple = "x86_64-unknown-linux-gnu"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"

!llvm.dependent-libraries = !{!0, !1}

!0 = !{!"foo"}
!1 = !{!"bar"}
