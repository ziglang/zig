target datalayout = "e-m:e-p:32:32-i64:64-n32:64-S128"
target triple = "wasm32-unknown-unknown"

declare void @llvm.wasm.throw(i32, i8*)

define void @bar(i8* %p) {
  call void @llvm.wasm.throw(i32 0, i8* %p)
  ret void
}
