; ModuleID = 'b.obj'
source_filename = "b.cpp"
target datalayout = "e-m:w-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-windows-msvc19.21.27702"

%struct.S = type { i32 (...)** }

; Function Attrs: norecurse nounwind readnone sspstrong uwtable
define dso_local void @"?foo@S@@UEAAXXZ"(%struct.S* nocapture %this) unnamed_addr #0 align 2 {
entry:
  ret void
}

attributes #0 = { norecurse nounwind readnone sspstrong uwtable "correctly-rounded-divide-sqrt-fp-math"="false" "disable-tail-calls"="false" "less-precise-fpmad"="false" "min-legal-vector-width"="0" "no-frame-pointer-elim"="false" "no-infs-fp-math"="false" "no-jump-tables"="false" "no-nans-fp-math"="false" "no-signed-zeros-fp-math"="false" "no-trapping-math"="false" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "unsafe-fp-math"="false" "use-soft-float"="false" }

!llvm.linker.options = !{!0, !1}
!llvm.module.flags = !{!2, !3, !4, !5}
!llvm.ident = !{!6}

!0 = !{!"/DEFAULTLIB:libcmt.lib"}
!1 = !{!"/DEFAULTLIB:oldnames.lib"}
!2 = !{i32 1, !"wchar_size", i32 2}
!3 = !{i32 7, !"PIC Level", i32 2}
!4 = !{i32 1, !"ThinLTO", i32 0}
!5 = !{i32 1, !"EnableSplitLTOUnit", i32 0}
!6 = !{!"clang version 9.0.0 (git@github.com:llvm/llvm-project.git 1a285c27fdf6407ceed3398e015d00559f5f533d)"}

^0 = module: (path: "b.obj", hash: (0, 0, 0, 0, 0))
^1 = gv: (name: "?foo@S@@UEAAXXZ", summaries: (function: (module: ^0, flags: (linkage: external, notEligibleToImport: 1, live: 0, dsoLocal: 1, canAutoHide: 0), insts: 1, funcFlags: (readNone: 1, readOnly: 0, noRecurse: 1, returnDoesNotAlias: 0, noInline: 0)))) ; guid = 6578172636330484861
