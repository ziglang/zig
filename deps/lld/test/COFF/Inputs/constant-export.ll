target datalayout = "e-m:x-p:32:32-i64:64-f80:32-n8:16:32-a:0:32-S32"
target triple = "i686-unknown-windows-msvc18.0.0"

@__CFConstantStringClassReference = common global [32 x i32] zeroinitializer, align 4

!llvm.linker.options = !{!0}
!0 = !{!" -export:___CFConstantStringClassReference,CONSTANT"}
