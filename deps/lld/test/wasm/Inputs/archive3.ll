target triple = "wasm32-unknown-unknown"

define i32 @bar() local_unnamed_addr #0 {
entry:
  ret i32 1
}

define void @archive3_symbol() local_unnamed_addr #0 {
entry:
  ret void
}
