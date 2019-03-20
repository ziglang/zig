; REQUIRES: ppc

; RUN: llvm-as %s -o %t.o
; RUN: ld.lld %t.o -o %t

target datalayout = "e-m:e-i64:64-n32:64"
target triple = "powerpc64le-unknown-linux-gnu"

define void @__start() {
  entry:
    ret void
}
