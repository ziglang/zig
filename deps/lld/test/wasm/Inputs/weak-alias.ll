target triple = "wasm32-unknown-unknown"

; Function Attrs: norecurse nounwind readnone
define i32 @direct_fn() #0 {
entry:
  ret i32 0
}

@alias_fn = weak alias i32 (), i32 ()* @direct_fn

define i32 @call_direct() #0 {
entry:
  %call = call i32 @direct_fn()
  ret i32 %call
}

define i32 @call_alias() #0 {
entry:
  %call = call i32 @alias_fn()
  ret i32 %call
}

define i32 @call_alias_ptr() #0 {
entry:
   %fnptr = alloca i32 ()*, align 8
   store i32 ()* @alias_fn, i32 ()** %fnptr, align 8
   %0 = load i32 ()*, i32 ()** %fnptr, align 8
   %call = call i32 %0()
   ret i32 %call
}

define i32 @call_direct_ptr() #0 {
entry:
  %fnptr = alloca i32 ()*, align 8
  store i32 ()* @direct_fn, i32 ()** %fnptr, align 8
  %0 = load i32 ()*, i32 ()** %fnptr, align 8
  %call = call i32 %0()
  ret i32 %call
}
