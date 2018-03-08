define weak i32 @weakFn() #0 {
entry:
  ret i32 1
}

define i32 @exportWeak1() {
entry:
    ret i32 ptrtoint (i32 ()* @weakFn to i32)
}

@weakGlobal = weak global i32 1
