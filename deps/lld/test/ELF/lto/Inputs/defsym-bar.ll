target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

declare void @this_is_bar1()
declare void @this_is_bar2()
declare void @this_is_bar3()

define hidden void @bar1() {
  call void @this_is_bar1()
  ret void
}

define hidden void @bar2() {
  call void @this_is_bar2()
  ret void
}

define hidden void @bar3() {
  call void @this_is_bar3()
  ret void
}
