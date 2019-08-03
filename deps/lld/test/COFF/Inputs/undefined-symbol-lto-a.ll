; ModuleID = 't.obj'
source_filename = "t.cpp"
target datalayout = "e-m:w-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-windows-msvc19.21.27702"

%struct.Init = type { %struct.S }
%struct.S = type { i32 (...)** }
%rtti.CompleteObjectLocator = type { i32, i32, i32, i32, i32, i32 }
%rtti.TypeDescriptor7 = type { i8**, i8*, [8 x i8] }
%rtti.ClassHierarchyDescriptor = type { i32, i32, i32, i32 }
%rtti.BaseClassDescriptor = type { i32, i32, i32, i32, i32, i32, i32 }

$"??_SS@@6B@" = comdat largest

$"??_R4S@@6B@" = comdat any

$"??_R0?AUS@@@8" = comdat any

$"??_R3S@@8" = comdat any

$"??_R2S@@8" = comdat any

$"??_R1A@?0A@EA@S@@8" = comdat any

@"?d@@3UInit@@A" = dso_local local_unnamed_addr global %struct.Init zeroinitializer, align 8
@anon.bcb2691509de99310dddb690fcdb4cdc.0 = private unnamed_addr constant { [2 x i8*] } { [2 x i8*] [i8* bitcast (%rtti.CompleteObjectLocator* @"??_R4S@@6B@" to i8*), i8* bitcast (void (%struct.S*)* @"?foo@S@@UEAAXXZ" to i8*)] }, comdat($"??_SS@@6B@"), !type !0
@"??_R4S@@6B@" = linkonce_odr constant %rtti.CompleteObjectLocator { i32 1, i32 0, i32 0, i32 trunc (i64 sub nuw nsw (i64 ptrtoint (%rtti.TypeDescriptor7* @"??_R0?AUS@@@8" to i64), i64 ptrtoint (i8* @__ImageBase to i64)) to i32), i32 trunc (i64 sub nuw nsw (i64 ptrtoint (%rtti.ClassHierarchyDescriptor* @"??_R3S@@8" to i64), i64 ptrtoint (i8* @__ImageBase to i64)) to i32), i32 trunc (i64 sub nuw nsw (i64 ptrtoint (%rtti.CompleteObjectLocator* @"??_R4S@@6B@" to i64), i64 ptrtoint (i8* @__ImageBase to i64)) to i32) }, comdat
@"??_7type_info@@6B@" = external constant i8*
@"??_R0?AUS@@@8" = linkonce_odr global %rtti.TypeDescriptor7 { i8** @"??_7type_info@@6B@", i8* null, [8 x i8] c".?AUS@@\00" }, comdat
@__ImageBase = external dso_local constant i8
@"??_R3S@@8" = linkonce_odr constant %rtti.ClassHierarchyDescriptor { i32 0, i32 0, i32 1, i32 trunc (i64 sub nuw nsw (i64 ptrtoint ([2 x i32]* @"??_R2S@@8" to i64), i64 ptrtoint (i8* @__ImageBase to i64)) to i32) }, comdat
@"??_R2S@@8" = linkonce_odr constant [2 x i32] [i32 trunc (i64 sub nuw nsw (i64 ptrtoint (%rtti.BaseClassDescriptor* @"??_R1A@?0A@EA@S@@8" to i64), i64 ptrtoint (i8* @__ImageBase to i64)) to i32), i32 0], comdat
@"??_R1A@?0A@EA@S@@8" = linkonce_odr constant %rtti.BaseClassDescriptor { i32 trunc (i64 sub nuw nsw (i64 ptrtoint (%rtti.TypeDescriptor7* @"??_R0?AUS@@@8" to i64), i64 ptrtoint (i8* @__ImageBase to i64)) to i32), i32 0, i32 0, i32 -1, i32 0, i32 64, i32 trunc (i64 sub nuw nsw (i64 ptrtoint (%rtti.ClassHierarchyDescriptor* @"??_R3S@@8" to i64), i64 ptrtoint (i8* @__ImageBase to i64)) to i32) }, comdat
@llvm.global_ctors = appending global [1 x { i32, void ()*, i8* }] [{ i32, void ()*, i8* } { i32 65535, void ()* @_GLOBAL__sub_I_t.cpp, i8* null }]

@"??_SS@@6B@" = unnamed_addr alias i8*, getelementptr inbounds ({ [2 x i8*] }, { [2 x i8*] }* @anon.bcb2691509de99310dddb690fcdb4cdc.0, i32 0, i32 0, i32 1)

declare dso_local void @"?undefined_ref@@YAXXZ"() local_unnamed_addr #0

declare dllimport void @"?foo@S@@UEAAXXZ"(%struct.S*) unnamed_addr #0

; Function Attrs: nounwind sspstrong uwtable
define internal void @_GLOBAL__sub_I_t.cpp() #1 {
entry:
  store i32 (...)** bitcast (i8** @"??_SS@@6B@" to i32 (...)**), i32 (...)*** getelementptr inbounds (%struct.Init, %struct.Init* @"?d@@3UInit@@A", i64 0, i32 0, i32 0), align 8
  tail call void @"?undefined_ref@@YAXXZ"() #2
  ret void
}

attributes #0 = { "correctly-rounded-divide-sqrt-fp-math"="false" "disable-tail-calls"="false" "less-precise-fpmad"="false" "no-frame-pointer-elim"="false" "no-infs-fp-math"="false" "no-nans-fp-math"="false" "no-signed-zeros-fp-math"="false" "no-trapping-math"="false" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "unsafe-fp-math"="false" "use-soft-float"="false" }
attributes #1 = { nounwind sspstrong uwtable "correctly-rounded-divide-sqrt-fp-math"="false" "disable-tail-calls"="false" "less-precise-fpmad"="false" "min-legal-vector-width"="0" "no-frame-pointer-elim"="false" "no-infs-fp-math"="false" "no-jump-tables"="false" "no-nans-fp-math"="false" "no-signed-zeros-fp-math"="false" "no-trapping-math"="false" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "unsafe-fp-math"="false" "use-soft-float"="false" }
attributes #2 = { nounwind }

!llvm.linker.options = !{!1, !2}
!llvm.module.flags = !{!3, !4, !5, !6}
!llvm.ident = !{!7}

!0 = !{i64 8, !"?AUS@@"}
!1 = !{!"/DEFAULTLIB:libcmt.lib"}
!2 = !{!"/DEFAULTLIB:oldnames.lib"}
!3 = !{i32 1, !"wchar_size", i32 2}
!4 = !{i32 7, !"PIC Level", i32 2}
!5 = !{i32 1, !"ThinLTO", i32 0}
!6 = !{i32 1, !"EnableSplitLTOUnit", i32 0}
!7 = !{!"clang version 9.0.0 (git@github.com:llvm/llvm-project.git 1a285c27fdf6407ceed3398e015d00559f5f533d)"}

^0 = module: (path: "t.obj", hash: (0, 0, 0, 0, 0))
^1 = gv: (name: "__ImageBase") ; guid = 434928772013489304
^2 = gv: (name: "??_R2S@@8", summaries: (variable: (module: ^0, flags: (linkage: linkonce_odr, notEligibleToImport: 1, live: 0, dsoLocal: 0, canAutoHide: 0), varFlags: (readonly: 0, writeonly: 0), refs: (^1, ^6)))) ; guid = 2160898732728284029
^3 = gv: (name: "llvm.global_ctors", summaries: (variable: (module: ^0, flags: (linkage: appending, notEligibleToImport: 1, live: 1, dsoLocal: 0, canAutoHide: 0), varFlags: (readonly: 0, writeonly: 0), refs: (^14)))) ; guid = 2412314959268824392
^4 = gv: (name: "?foo@S@@UEAAXXZ") ; guid = 6578172636330484861
^5 = gv: (name: "??_SS@@6B@", summaries: (alias: (module: ^0, flags: (linkage: external, notEligibleToImport: 1, live: 0, dsoLocal: 0, canAutoHide: 0), aliasee: ^10))) ; guid = 8774897714842691026
^6 = gv: (name: "??_R1A@?0A@EA@S@@8", summaries: (variable: (module: ^0, flags: (linkage: linkonce_odr, notEligibleToImport: 1, live: 0, dsoLocal: 0, canAutoHide: 0), varFlags: (readonly: 0, writeonly: 0), refs: (^11, ^1, ^8)))) ; guid = 9397802696236423453
^7 = gv: (name: "?undefined_ref@@YAXXZ") ; guid = 9774674600202276560
^8 = gv: (name: "??_R3S@@8", summaries: (variable: (module: ^0, flags: (linkage: linkonce_odr, notEligibleToImport: 1, live: 0, dsoLocal: 0, canAutoHide: 0), varFlags: (readonly: 0, writeonly: 0), refs: (^1, ^2)))) ; guid = 10685958509605791599
^9 = gv: (name: "??_7type_info@@6B@") ; guid = 10826752452437539368
^10 = gv: (name: "anon.bcb2691509de99310dddb690fcdb4cdc.0", summaries: (variable: (module: ^0, flags: (linkage: private, notEligibleToImport: 1, live: 0, dsoLocal: 1, canAutoHide: 0), varFlags: (readonly: 0, writeonly: 0), vTableFuncs: ((virtFunc: ^4, offset: 8)), refs: (^13, ^4)))) ; guid = 11510395461204283992
^11 = gv: (name: "??_R0?AUS@@@8", summaries: (variable: (module: ^0, flags: (linkage: linkonce_odr, notEligibleToImport: 1, live: 0, dsoLocal: 0, canAutoHide: 0), varFlags: (readonly: 0, writeonly: 0), refs: (^9)))) ; guid = 12346607659584231960
^12 = gv: (name: "?d@@3UInit@@A", summaries: (variable: (module: ^0, flags: (linkage: external, notEligibleToImport: 1, live: 0, dsoLocal: 1, canAutoHide: 0), varFlags: (readonly: 1, writeonly: 1)))) ; guid = 14563354643524156382
^13 = gv: (name: "??_R4S@@6B@", summaries: (variable: (module: ^0, flags: (linkage: linkonce_odr, notEligibleToImport: 1, live: 0, dsoLocal: 0, canAutoHide: 0), varFlags: (readonly: 0, writeonly: 0), refs: (^13, ^11, ^1, ^8)))) ; guid = 14703528065171087394
^14 = gv: (name: "_GLOBAL__sub_I_t.cpp", summaries: (function: (module: ^0, flags: (linkage: internal, notEligibleToImport: 1, live: 0, dsoLocal: 1, canAutoHide: 0), insts: 3, calls: ((callee: ^7)), refs: (^12, ^5)))) ; guid = 15085897428757412588
^15 = typeidCompatibleVTable: (name: "?AUS@@", summary: ((offset: 8, ^10))) ; guid = 13986515119763165370
