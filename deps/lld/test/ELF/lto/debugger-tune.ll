; REQUIRES: x86
; RUN: llvm-as %s -o %t.o

; Here we verify that -debugger-tune=<value> option is
; handled by LLD. DWARF linkage name attributes are optional,
; they normally present, but are missing for SCE debugger tune.

; RUN: ld.lld %t.o -o %t.exe
; RUN: llvm-dwarfdump %t.exe | FileCheck %s
; CHECK: DW_AT_linkage_name ("name_of_foo")

; RUN: ld.lld -plugin-opt=-debugger-tune=sce %t.o -o %t.exe
; RUN: llvm-dwarfdump %t.exe | FileCheck --check-prefix=SCE %s
; SCE-NOT: name_of_foo

target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

@foo = global i32 0, align 4, !dbg !0

!llvm.dbg.cu = !{!5}
!llvm.module.flags = !{!8, !9}

!0 = !DIGlobalVariableExpression(var: !1, expr: !DIExpression())
!1 = distinct !DIGlobalVariable(name: "global_foo", linkageName: "name_of_foo", scope: !2,
     file: !3, line: 2, type: !4, isLocal: false, isDefinition: true)
!2 = !DINamespace(name: "test", scope: null)
!3 = !DIFile(filename: "test.cpp", directory: "/home/tests")
!4 = !DIBasicType(name: "int", size: 32, encoding: DW_ATE_signed)
!5 = distinct !DICompileUnit(language: DW_LANG_C_plus_plus, file: !3, producer: "clang",
     isOptimized: false, runtimeVersion: 0, emissionKind: FullDebug, enums: !6, globals: !7)
!6 = !{}
!7 = !{!0}
!8 = !{i32 2, !"Dwarf Version", i32 4}
!9 = !{i32 2, !"Debug Info Version", i32 3}
