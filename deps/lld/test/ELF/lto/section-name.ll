; REQUIRES: x86
; RUN: llvm-as %s -o %t.o
; RUN: ld.lld %t.o -o %t.so -shared
; RUN: llvm-readelf -S %t.so | FileCheck %s
; RUN: ld.lld %t.o -o %t.so -shared --gc-sections
; RUN: llvm-readelf -S %t.so | FileCheck --check-prefix=GC %s

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

@foo = hidden global i32 42, section "foo_section"
@bar = hidden global i32 42, section "bar_section"
@zed = hidden global i32 42, section "zed_section"

@__start_foo_section = external global i32
@__stop_bar_section = external global i32

define hidden i32* @use1() {
  ret i32* @__start_foo_section
}

define i32* @use2() {
  ret i32* @__stop_bar_section
}

; CHECK-NOT: zed_section
; CHECK:     foo_section PROGBITS
; CHECK-NEXT:     bar_section PROGBITS
; CHECK-NOT: zed_section

; GC-NOT: zed_section
; GC-NOT: foo_section
; GC:     bar_section PROGBITS
; GC-NOT: zed_section
; GC-NOT: foo_section
