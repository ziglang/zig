target triple = "wasm32-unknown-unknown"

$inlineFn = comdat any
@constantData = weak_odr constant [3 x i8] c"abc", comdat($inlineFn)
define linkonce_odr i32 @inlineFn() comdat {
entry:
  ret i32 ptrtoint ([3 x i8]* @constantData to i32)
}

define i32 @callInline1() {
entry:
    ret i32 ptrtoint (i32 ()* @inlineFn to i32)
}
