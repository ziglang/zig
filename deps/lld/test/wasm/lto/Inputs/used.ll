target datalayout = "e-m:e-p:32:32-i64:64-n32:64-S128"
target triple = "wasm32-unknown-unknown"

@foo = hidden global i32 1

define hidden void @bar() {
  ret void
}
