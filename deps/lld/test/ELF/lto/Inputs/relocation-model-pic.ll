target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

@foo = external global i32
define i32 @main() {
  %t = load i32, i32* @foo
  ret i32 %t
}

!llvm.module.flags = !{!0}
!0 = !{i32 1, !"PIC Level", i32 2}
