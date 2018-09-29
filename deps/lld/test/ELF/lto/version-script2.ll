; REQUIRES: x86
; RUN: llvm-as %s -o %t.o
; RUN: echo "VER1 {};" > %t.script
; RUN: ld.lld %t.o -o %t.so -shared --version-script %t.script
; RUN: llvm-readobj -dyn-symbols %t.so | FileCheck %s

; test that we have the correct version.
; CHECK: Name: foo@@VER1 (

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

module asm ".global foo"
module asm "foo:"
module asm ".symver foo,foo@@@VER1"
