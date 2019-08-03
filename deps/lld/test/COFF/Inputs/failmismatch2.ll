; ModuleID = 'test2.cpp'

; Function Attrs: noinline norecurse nounwind optnone sspstrong uwtable
define dso_local i32 @main() #0 {
  %1 = alloca i32, align 4
  store i32 0, i32* %1, align 4
  %2 = call i32 @"?f@@YAHXZ"()
  ret i32 %2
}

declare dso_local i32 @"?f@@YAHXZ"() #1

!llvm.linker.options = !{!0}
!llvm.module.flags = !{!1, !2}
!llvm.ident = !{!3}

!0 = !{!"/FAILIFMISMATCH:\22TEST=2\22"}
!1 = !{i32 1, !"wchar_size", i32 2}
!2 = !{i32 7, !"PIC Level", i32 2}
!3 = !{!"clang version 7.0.1 (tags/RELEASE_701/final)"}
