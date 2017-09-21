target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-scei-ps4"

define i32 @blah(i32 %meh) #0 {
entry:
  %meh.addr = alloca i32, align 4
  store i32 %meh, i32* %meh.addr, align 4
  %0 = load i32, i32* %meh.addr, align 4
  %sub = sub nsw i32 %0, 48
  ret i32 %sub
}
