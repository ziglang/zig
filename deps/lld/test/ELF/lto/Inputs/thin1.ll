target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-scei-ps4"

define i32 @foo(i32 %goo) {
entry:
  %goo.addr = alloca i32, align 4
  store i32 %goo, i32* %goo.addr, align 4
  %0 = load i32, i32* %goo.addr, align 4
  %1 = load i32, i32* %goo.addr, align 4
  %mul = mul nsw i32 %0, %1
  ret i32 %mul
}
