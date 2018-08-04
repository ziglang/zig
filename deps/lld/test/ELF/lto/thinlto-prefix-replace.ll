; REQUIRES: x86
; Check that changing the output path via thinlto-prefix-replace works
; RUN: mkdir -p %t/oldpath
; RUN: opt -module-summary %s -o %t/oldpath/thinlto_prefix_replace.o

; Ensure that there is no existing file at the new path, so we properly
; test the creation of the new file there.
; RUN: rm -f %t/newpath/thinlto_prefix_replace.o.thinlto.bc
; RUN: ld.lld --plugin-opt=thinlto-index-only --plugin-opt=thinlto-prefix-replace="%t/oldpath/;%t/newpath/" -shared %t/oldpath/thinlto_prefix_replace.o -o %t/thinlto_prefix_replace
; RUN: ls %t/newpath/thinlto_prefix_replace.o.thinlto.bc

; Ensure that lld generates error if prefix replace option does not have 'old;new' format
; RUN: rm -f %t/newpath/thinlto_prefix_replace.o.thinlto.bc
; RUN: not ld.lld --plugin-opt=thinlto-index-only --plugin-opt=thinlto-prefix-replace=abc:def -shared %t/oldpath/thinlto_prefix_replace.o -o %t/thinlto_prefix_replace 2>&1 | FileCheck %s --check-prefix=ERR
; ERR: --plugin-opt=thinlto-prefix-replace= expects 'old;new' format, but got abc:def

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

define void @f() {
entry:
  ret void
}
