; ModuleID = 'hi.c'
source_filename = "hi.c"
target datalayout = "e-m:e-p:32:32-i64:64-n32:64-S128"
target triple = "wasm32-unknown-unknown"

; // hi.c:
; extern void foo(int);
;
; int test(int t) {
;   return t * t;
; }
;
; int _start() {
;   foo(test(10));
;   return 0;
; }

; Function Attrs: nounwind readnone
define hidden i32 @test(i32 %t) local_unnamed_addr #0 !dbg !7 {
entry:
  call void @llvm.dbg.value(metadata i32 %t, metadata !12, metadata !DIExpression()), !dbg !13
  %mul = mul nsw i32 %t, %t, !dbg !14
  ret i32 %mul, !dbg !15
}

; Function Attrs: nounwind
define hidden i32 @_start() local_unnamed_addr #1 !dbg !16 {
entry:
  tail call void @foo(i32 100) #4, !dbg !19
  ret i32 0, !dbg !20
}

declare void @foo(i32) local_unnamed_addr #2

; Function Attrs: nounwind readnone speculatable
declare void @llvm.dbg.value(metadata, metadata, metadata) #3

attributes #0 = { nounwind readnone "correctly-rounded-divide-sqrt-fp-math"="false" "disable-tail-calls"="false" "less-precise-fpmad"="false" "no-frame-pointer-elim"="false" "no-infs-fp-math"="false" "no-jump-tables"="false" "no-nans-fp-math"="false" "no-signed-zeros-fp-math"="false" "no-trapping-math"="false" "stack-protector-buffer-size"="8" "target-cpu"="generic" "unsafe-fp-math"="false" "use-soft-float"="false" }
attributes #1 = { nounwind "correctly-rounded-divide-sqrt-fp-math"="false" "disable-tail-calls"="false" "less-precise-fpmad"="false" "no-frame-pointer-elim"="false" "no-infs-fp-math"="false" "no-jump-tables"="false" "no-nans-fp-math"="false" "no-signed-zeros-fp-math"="false" "no-trapping-math"="false" "stack-protector-buffer-size"="8" "target-cpu"="generic" "unsafe-fp-math"="false" "use-soft-float"="false" }
attributes #2 = { "correctly-rounded-divide-sqrt-fp-math"="false" "disable-tail-calls"="false" "less-precise-fpmad"="false" "no-frame-pointer-elim"="false" "no-infs-fp-math"="false" "no-nans-fp-math"="false" "no-signed-zeros-fp-math"="false" "no-trapping-math"="false" "stack-protector-buffer-size"="8" "target-cpu"="generic" "unsafe-fp-math"="false" "use-soft-float"="false" }
attributes #3 = { nounwind readnone speculatable }
attributes #4 = { nounwind }

!llvm.dbg.cu = !{!0}
!llvm.module.flags = !{!3, !4, !5}
!llvm.ident = !{!6}

!0 = distinct !DICompileUnit(language: DW_LANG_C99, file: !1, producer: "clang version 7.0.0 (trunk 331321)", isOptimized: true, runtimeVersion: 0, emissionKind: FullDebug, enums: !2)
!1 = !DIFile(filename: "hi.c", directory: "/Users/yury/llvmwasm")
!2 = !{}
!3 = !{i32 2, !"Dwarf Version", i32 4}
!4 = !{i32 2, !"Debug Info Version", i32 3}
!5 = !{i32 1, !"wchar_size", i32 4}
!6 = !{!"clang version 7.0.0 (trunk 331321)"}
!7 = distinct !DISubprogram(name: "test", scope: !1, file: !1, line: 3, type: !8, isLocal: false, isDefinition: true, scopeLine: 3, flags: DIFlagPrototyped, isOptimized: true, unit: !0, retainedNodes: !11)
!8 = !DISubroutineType(types: !9)
!9 = !{!10, !10}
!10 = !DIBasicType(name: "int", size: 32, encoding: DW_ATE_signed)
!11 = !{!12}
!12 = !DILocalVariable(name: "t", arg: 1, scope: !7, file: !1, line: 3, type: !10)
!13 = !DILocation(line: 3, column: 14, scope: !7)
!14 = !DILocation(line: 4, column: 12, scope: !7)
!15 = !DILocation(line: 4, column: 3, scope: !7)
!16 = distinct !DISubprogram(name: "_start", scope: !1, file: !1, line: 7, type: !17, isLocal: false, isDefinition: true, scopeLine: 7, isOptimized: true, unit: !0, retainedNodes: !2)
!17 = !DISubroutineType(types: !18)
!18 = !{!10}
!19 = !DILocation(line: 8, column: 3, scope: !16)
!20 = !DILocation(line: 9, column: 3, scope: !16)
