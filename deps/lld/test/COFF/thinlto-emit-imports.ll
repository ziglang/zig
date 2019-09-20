; REQUIRES: x86

; Generate summary sections and test lld handling.
; RUN: opt -module-summary %s -o %t1.obj
; RUN: opt -module-summary %p/Inputs/thinlto.ll -o %t2.obj

; Include a file with an empty module summary index, to ensure that the expected
; output files are created regardless, for a distributed build system.
; RUN: opt -module-summary %p/Inputs/thinlto-empty.ll -o %t3.obj

; Ensure lld generates imports files if requested for distributed backends.
; RUN: rm -f %t3.obj.imports %t3.obj.thinlto.bc
; RUN: lld-link -entry:main -thinlto-index-only \
; RUN:     -thinlto-emit-imports-files %t1.obj %t2.obj %t3.obj -out:%t4.exe

; The imports file for this module contains the bitcode file for
; Inputs/thinlto.ll
; RUN: cat %t1.obj.imports | count 1
; RUN: cat %t1.obj.imports | FileCheck %s --check-prefix=IMPORTS1
; IMPORTS1: thinlto-emit-imports.ll.tmp2.obj

; The imports file for Input/thinlto.ll is empty as it does not import anything.
; RUN: cat %t2.obj.imports | count 0

; The imports file for Input/thinlto_empty.ll is empty but should exist.
; RUN: cat %t3.obj.imports | count 0

; The index file should be created even for the input with an empty summary.
; RUN: ls %t3.obj.thinlto.bc

; Ensure lld generates error if unable to write to imports file.
; RUN: rm -f %t3.obj.imports
; RUN: touch %t3.obj.imports
; RUN: chmod 400 %t3.obj.imports
; RUN: not lld-link -entry:main -thinlto-index-only \
; RUN:     -thinlto-emit-imports-files %t1.obj %t2.obj %t3.obj \
; RUN:     -out:%t4.exe 2>&1 | FileCheck %s --check-prefix=ERR
; ERR: cannot open {{.*}}3.obj.imports: {{P|p}}ermission denied

; Ensure lld doesn't generate import files when thinlto-index-only is not enabled
; RUN: rm -f %t1.obj.imports
; RUN: rm -f %t2.obj.imports
; RUN: rm -f %t3.obj.imports
; RUN: lld-link -entry:main -thinlto-emit-imports-files \
; RUN:     %t1.obj %t2.obj %t3.obj -out:%t4.exe
; RUN: not ls %t1.obj.imports
; RUN: not ls %t2.obj.imports
; RUN: not ls %t3.obj.imports

target datalayout = "e-m:w-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-windows-msvc19.0.24215"

declare void @g(...)

define void @main() {
entry:
  call void (...) @g()
  ret void
}
