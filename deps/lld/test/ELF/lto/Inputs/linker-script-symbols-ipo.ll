target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

declare i32 @bar()

define i32 @_start() {
  %1 = tail call i32 @bar()
  ret i32 %1
}
