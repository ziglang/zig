; ModuleID = 'test.cpp'

; Function Attrs: noinline nounwind optnone sspstrong uwtable
define dso_local i32 @"?f@@YAHXZ"() #0 {
  ret i32 0
}

!llvm.linker.options = !{!0}
!llvm.module.flags = !{!1, !2}
!llvm.ident = !{!3}

!0 = !{!"/FAILIFMISMATCH:\22TEST=1\22"}
!1 = !{i32 1, !"wchar_size", i32 2}
!2 = !{i32 7, !"PIC Level", i32 2}
!3 = !{!"clang version 7.0.1 (tags/RELEASE_701/final)"}
