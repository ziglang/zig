; ModuleID = 'hi_foo.c'
source_filename = "hi_foo.c"
target datalayout = "e-m:e-p:32:32-i64:64-n32:64-S128"
target triple = "wasm32-unknown-unknown"

; // hi_foo.c:
; int y[2] = {23, 41};
;
; void foo(int p) {
;   y[p & 1]++;
; }
;
; // Will be GCed, but remain visible in debug info
; int z[2] = {1, 2};

@y = hidden local_unnamed_addr global [2 x i32] [i32 23, i32 41], align 4, !dbg !0
@z = hidden local_unnamed_addr global [2 x i32] [i32 1, i32 2], align 4, !dbg !6

; Function Attrs: nounwind
define hidden void @foo(i32 %p) local_unnamed_addr #0 !dbg !16 {
entry:
  call void @llvm.dbg.value(metadata i32 %p, metadata !20, metadata !DIExpression()), !dbg !21
  %and = and i32 %p, 1, !dbg !22
  %arrayidx = getelementptr inbounds [2 x i32], [2 x i32]* @y, i32 0, i32 %and, !dbg !23
  %0 = load i32, i32* %arrayidx, align 4, !dbg !24, !tbaa !25
  %inc = add nsw i32 %0, 1, !dbg !24
  store i32 %inc, i32* %arrayidx, align 4, !dbg !24, !tbaa !25
  ret void, !dbg !29
}

; Function Attrs: nounwind readnone speculatable
declare void @llvm.dbg.value(metadata, metadata, metadata) #1

attributes #0 = { nounwind "correctly-rounded-divide-sqrt-fp-math"="false" "disable-tail-calls"="false" "less-precise-fpmad"="false" "no-frame-pointer-elim"="false" "no-infs-fp-math"="false" "no-jump-tables"="false" "no-nans-fp-math"="false" "no-signed-zeros-fp-math"="false" "no-trapping-math"="false" "stack-protector-buffer-size"="8" "target-cpu"="generic" "unsafe-fp-math"="false" "use-soft-float"="false" }
attributes #1 = { nounwind readnone speculatable }

!llvm.dbg.cu = !{!2}
!llvm.module.flags = !{!12, !13, !14}
!llvm.ident = !{!15}

!0 = !DIGlobalVariableExpression(var: !1, expr: !DIExpression())
!1 = distinct !DIGlobalVariable(name: "y", scope: !2, file: !3, line: 1, type: !8, isLocal: false, isDefinition: true)
!2 = distinct !DICompileUnit(language: DW_LANG_C99, file: !3, producer: "clang version 7.0.0 (trunk 332913) (llvm/trunk 332919)", isOptimized: true, runtimeVersion: 0, emissionKind: FullDebug, enums: !4, globals: !5)
!3 = !DIFile(filename: "hi_foo.c", directory: "/usr/local/google/home/sbc/dev/wasm/llvm-build")
!4 = !{}
!5 = !{!0, !6}
!6 = !DIGlobalVariableExpression(var: !7, expr: !DIExpression())
!7 = distinct !DIGlobalVariable(name: "z", scope: !2, file: !3, line: 8, type: !8, isLocal: false, isDefinition: true)
!8 = !DICompositeType(tag: DW_TAG_array_type, baseType: !9, size: 64, elements: !10)
!9 = !DIBasicType(name: "int", size: 32, encoding: DW_ATE_signed)
!10 = !{!11}
!11 = !DISubrange(count: 2)
!12 = !{i32 2, !"Dwarf Version", i32 4}
!13 = !{i32 2, !"Debug Info Version", i32 3}
!14 = !{i32 1, !"wchar_size", i32 4}
!15 = !{!"clang version 7.0.0 (trunk 332913) (llvm/trunk 332919)"}
!16 = distinct !DISubprogram(name: "foo", scope: !3, file: !3, line: 3, type: !17, isLocal: false, isDefinition: true, scopeLine: 3, flags: DIFlagPrototyped, isOptimized: true, unit: !2, retainedNodes: !19)
!17 = !DISubroutineType(types: !18)
!18 = !{null, !9}
!19 = !{!20}
!20 = !DILocalVariable(name: "p", arg: 1, scope: !16, file: !3, line: 3, type: !9)
!21 = !DILocation(line: 3, column: 14, scope: !16)
!22 = !DILocation(line: 4, column: 7, scope: !16)
!23 = !DILocation(line: 4, column: 3, scope: !16)
!24 = !DILocation(line: 4, column: 11, scope: !16)
!25 = !{!26, !26, i64 0}
!26 = !{!"int", !27, i64 0}
!27 = !{!"omnipotent char", !28, i64 0}
!28 = !{!"Simple C/C++ TBAA"}
!29 = !DILocation(line: 5, column: 1, scope: !16)
