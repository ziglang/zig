; REQUIRES: x86
; Check that changing the output path via thinlto-prefix-replace works
; RUN: mkdir -p %t/oldpath
; RUN: opt -module-summary %s -o %t/oldpath/t.obj

; Ensure that there is no existing file at the new path, so we properly
; test the creation of the new file there.
; RUN: rm -f %t/newpath/t.obj.thinlto.bc
; RUN: lld-link -entry:main -thinlto-index-only \
; RUN:     -thinlto-prefix-replace:"%t/oldpath/;%t/newpath/" %t/oldpath/t.obj \
; RUN:     -out:%t/t.exe
; RUN: ls %t/newpath/t.obj.thinlto.bc

; Ensure that lld errors if prefix replace option is not in 'old;new' format.
; RUN: rm -f %t/newpath/t.obj.thinlto.bc
; RUN: not lld-link -entry:main -thinlto-index-only \
; RUN:     -thinlto-prefix-replace:"abc:def" %t/oldpath/t.obj \
; RUN:     -out:%t/t.exe 2>&1 | FileCheck --check-prefix=ERR %s
; ERR: -thinlto-prefix-replace: expects 'old;new' format, but got abc:def

target datalayout = "e-m:w-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-windows-msvc19.0.24215"

define void @main() {
  ret void
}
