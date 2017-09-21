target triple = "x86_64-unknown-linux-gnu"
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"

%zed = type { i16 }
define void @bar(%zed* %this)  {
  store %zed* %this, %zed** null
  ret void
}
