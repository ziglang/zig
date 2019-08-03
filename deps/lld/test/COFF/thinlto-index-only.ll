; REQUIRES: x86

; Basic ThinLTO tests.
; RUN: opt -thinlto-bc %s -o %t1.obj
; RUN: opt -thinlto-bc %p/Inputs/thinlto.ll -o %t2.obj
; RUN: opt -thinlto-bc %p/Inputs/thinlto-empty.ll -o %t3.obj

; Ensure lld generates an index and not a binary if requested.
; RUN: rm -f %t4.exe
; RUN: lld-link -thinlto-index-only -entry:main %t1.obj %t2.obj -out:%t4.exe
; RUN: llvm-bcanalyzer -dump %t1.obj.thinlto.bc | FileCheck %s --check-prefix=BACKEND1
; RUN: llvm-bcanalyzer -dump %t2.obj.thinlto.bc | FileCheck %s --check-prefix=BACKEND2
; RUN: not test -e %t4.exe

; The backend index for this module contains summaries from itself and
; Inputs/thinlto.ll, as it imports from the latter.
; BACKEND1: <MODULE_STRTAB_BLOCK
; BACKEND1-NEXT: <ENTRY {{.*}} record string = '{{.*}}thinlto-index-only.ll.tmp{{.*}}.obj'
; BACKEND1: <ENTRY {{.*}} record string = '{{.*}}thinlto-index-only.ll.tmp{{.*}}.obj'
; BACKEND1-NOT: <ENTRY
; BACKEND1: </MODULE_STRTAB_BLOCK
; BACKEND1: <GLOBALVAL_SUMMARY_BLOCK
; BACKEND1: <VERSION
; BACKEND1: <FLAGS
; BACKEND1: <VALUE_GUID op0={{1|2}} op1={{-5300342847281564238|-2624081020897602054}}
; BACKEND1: <VALUE_GUID op0={{1|2}} op1={{-5300342847281564238|-2624081020897602054}}
; BACKEND1: <COMBINED
; BACKEND1: <COMBINED
; BACKEND1: </GLOBALVAL_SUMMARY_BLOCK

; The backend index for Input/thinlto.ll contains summaries from itself only,
; as it does not import anything.
; BACKEND2: <MODULE_STRTAB_BLOCK
; BACKEND2-NEXT: <ENTRY {{.*}} record string = '{{.*}}thinlto-index-only.ll.tmp2.obj'
; BACKEND2-NOT: <ENTRY
; BACKEND2: </MODULE_STRTAB_BLOCK
; BACKEND2-NEXT: <GLOBALVAL_SUMMARY_BLOCK
; BACKEND2-NEXT: <VERSION
; BACKEND2-NEXT: <FLAGS
; BACKEND2-NEXT: <VALUE_GUID op0=1 op1=-5300342847281564238
; BACKEND2-NEXT: <COMBINED
; BACKEND2-NEXT: </GLOBALVAL_SUMMARY_BLOCK

target datalayout = "e-m:w-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-windows-msvc19.0.24215"

declare void @g(...)

define void @main() {
  call void (...) @g()
  ret void
}
