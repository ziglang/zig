define hidden void @myctor() {
entry:
  ret void
}

define hidden void @mydtor() {
entry:
  %ptr = alloca i32
  ret void
}

@llvm.global_ctors = appending global [1 x { i32, void ()*, i8* }] [{ i32, void ()*, i8* } { i32 65535, void ()* @myctor, i8* null }]

@llvm.global_dtors = appending global [1 x { i32, void ()*, i8* }] [{ i32, void ()*, i8* } { i32 65535, void ()* @mydtor, i8* null }]
