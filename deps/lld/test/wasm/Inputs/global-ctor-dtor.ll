target triple = "wasm32-unknown-unknown"

define hidden void @myctor() {
entry:
  ret void
}

define hidden void @mydtor() {
entry:
  %ptr = alloca i32
  ret void
}

@llvm.global_ctors = appending global [3 x { i32, void ()*, i8* }] [
  { i32, void ()*, i8* } { i32 2002, void ()* @myctor, i8* null },
  { i32, void ()*, i8* } { i32 101, void ()* @myctor, i8* null },
  { i32, void ()*, i8* } { i32 202, void ()* @myctor, i8* null }
]

@llvm.global_dtors = appending global [3 x { i32, void ()*, i8* }] [
  { i32, void ()*, i8* } { i32 2002, void ()* @mydtor, i8* null },
  { i32, void ()*, i8* } { i32 101, void ()* @mydtor, i8* null },
  { i32, void ()*, i8* } { i32 202, void ()* @mydtor, i8* null }
]
