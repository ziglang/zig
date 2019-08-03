; REQUIRES: x86
; Set up an import library for a DLL that will do the indirect call.
; RUN: echo -e 'LIBRARY library\nEXPORTS\n  do_indirect_call\n' > %t.def
; RUN: lld-link -lib -def:%t.def -out:%t.lib -machine:x64

; Generate an object that will have the load configuration normally provided by
; the CRT.
; RUN: llvm-mc -triple x86_64-windows-msvc -filetype=obj %S/Inputs/loadconfig-cfg-x64.s -o %t.ldcfg.obj

; RUN: llvm-as %s -o %t.bc
; RUN: lld-link -entry:main -guard:cf -dll %t.bc %t.lib %t.ldcfg.obj -out:%t.dll
; RUN: llvm-readobj --coff-load-config %t.dll | FileCheck %s

; There must be *two* entries in the table: DLL entry point, and my_handler.

; CHECK:      LoadConfig [
; CHECK:        GuardCFFunctionTable: 0x{{[^0].*}}
; CHECK-NEXT:   GuardCFFunctionCount: 2
; CHECK-NEXT:   GuardFlags: 0x10500
; CHECK:      ]
; CHECK:      GuardFidTable [
; CHECK-NEXT:   0x180{{.*}}
; CHECK-NEXT:   0x180{{.*}}
; CHECK-NEXT: ]

target datalayout = "e-m:w-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-windows-msvc19.12.25835"

declare dllimport void @do_indirect_call(void ()*)

define dso_local i32 @main() local_unnamed_addr {
entry:
  tail call void @do_indirect_call(void ()* nonnull @my_handler)
  ret i32 0
}

define dso_local void @my_handler() {
entry:
  ret void
}
