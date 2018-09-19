; REQUIRES: x86

; Generate summary sections and test lld handling.
; RUN: opt -module-summary %s -o %t1.o
; RUN: opt -module-summary %p/Inputs/thinlto.ll -o %t2.o

; Include a file with an empty module summary index, to ensure that the expected
; output files are created regardless, for a distributed build system.
; RUN: opt -module-summary %p/Inputs/thinlto_empty.ll -o %t3.o

; Ensure lld generates imports files if requested for distributed backends.
; RUN: rm -f %t3.o.imports %t3.o.thinlto.bc
; RUN: ld.lld --plugin-opt=thinlto-index-only --plugin-opt=thinlto-emit-imports-files -shared %t1.o %t2.o %t3.o -o %t4

; The imports file for this module contains the bitcode file for
; Inputs/thinlto.ll
; RUN: cat %t1.o.imports | count 1
; RUN: cat %t1.o.imports | FileCheck %s --check-prefix=IMPORTS1
; IMPORTS1: thinlto-emit-imports.ll.tmp2.o

; The imports file for Input/thinlto.ll is empty as it does not import anything.
; RUN: cat %t2.o.imports | count 0

; The imports file for Input/thinlto_empty.ll is empty but should exist.
; RUN: cat %t3.o.imports | count 0

; The index file should be created even for the input with an empty summary.
; RUN: ls %t3.o.thinlto.bc

; Ensure lld generates error if unable to write to imports file.
; RUN: rm -f %t3.o.imports
; RUN: touch %t3.o.imports
; RUN: chmod 400 %t3.o.imports
; RUN: not ld.lld --plugin-opt=thinlto-index-only --plugin-opt=thinlto-emit-imports-files -shared %t1.o %t2.o %t3.o -o %t4 2>&1 | FileCheck %s --check-prefix=ERR
; ERR: cannot open {{.*}}3.o.imports: {{P|p}}ermission denied

; Ensure lld doesn't generate import files when thinlto-index-only is not enabled
; RUN: rm -f %t1.o.imports
; RUN: rm -f %t2.o.imports
; RUN: rm -f %t3.o.imports
; RUN: ld.lld --plugin-opt=thinlto-emit-imports-files -shared %t1.o %t2.o %t3.o -o %t4
; RUN: not ls %t1.o.imports
; RUN: not ls %t2.o.imports
; RUN: not ls %t3.o.imports

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

declare void @g(...)

define void @f() {
entry:
  call void (...) @g()
  ret void
}
