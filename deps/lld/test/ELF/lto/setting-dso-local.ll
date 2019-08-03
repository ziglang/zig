; REQUIRES: x86
; RUN: llvm-as %s -o %t1.o
; RUN: not ld.lld -o %t %t1.o 2>&1 | FileCheck %s

; CHECK: undefined hidden symbol: foobar

; We used to crash setting foobar to non-dso_local

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

@foobar = external hidden global i32
define i32* @_start() {
  ret i32* @foobar
}
